from datetime import datetime

from firebase_functions import firestore_fn
from firebase_admin import initialize_app, firestore

# Initialize Firebase Admin and Firestore client
initialize_app()
db = firestore.client()

# -------------------------------------------------------------
# Haversine helper: compute distance between two GPS points
# -------------------------------------------------------------

EARTH_RADIUS = 6371000  # meters


def _to_rad(deg: float) -> float:
    """Convert degrees to radians."""
    from math import pi
    return (deg * pi) / 180.0


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Compute great-circle distance in meters between two (lat, lon) points.
    """
    from math import sin, cos, atan2, sqrt

    phi1 = _to_rad(lat1)
    phi2 = _to_rad(lat2)
    dphi = _to_rad(lat2 - lat1)
    dlambda = _to_rad(lon2 - lon1)

    a = (
        sin(dphi / 2) ** 2
        + cos(phi1) * cos(phi2) * sin(dlambda / 2) ** 2
    )
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return EARTH_RADIUS * c


# -------------------------------------------------------------
# Placeholder: FCM sending (log only for now)
# -------------------------------------------------------------

def send_geofence_alert_fcm(group_id: str, member_id: str, distance: float) -> None:
    """
    Placeholder for real FCM sending.
    Currently just logs a message.
    """
    print(
        f"[GEOFENCE ALERT] member={member_id} group={group_id} "
        f"is OUTSIDE geofence (distance={distance:.2f}m)"
    )


# -------------------------------------------------------------
# Main Cloud Function:
# Trigger on write to users/{phoneNumber}
# -------------------------------------------------------------

@firestore_fn.on_document_written(document="users/{phoneNumber}")
def on_user_location_update(event) -> None:
    """
    This function runs whenever a user document is created/updated/deleted.

    Firestore structure (based on your Dart models):

      - users/{phoneNumber}
          - phoneNumber, fullName, nationalId, createdAt (string)
          - lastKnownLocation: AppLocation.toMap()
                { latitude, longitude, id, nameEn, nameAr, ... }

      - groups/{groupId}
          - groupId, groupName, ...
          - geofenceConfig: {
                type: "dynamicLeader" | "staticLocation",
                radiusInMeters: number,
                targetMemberIds: [phoneNumber, ...],
                staticLatitude?: number,
                staticLongitude?: number
            }
          - memberIds: [phoneNumber, ...]

      - groups/{groupId}/geofences/{memberId}
          - groupId: string
          - memberId: string           (phoneNumber)
          - isOutsideGeofence: bool
          - updatedAt: ISO string
          - distanceMeters?: number

    The goal:
      - For each location update on users/{phoneNumber}:
          * find all groups where this member exists in memberIds
          * if geofenceConfig exists AND member is in targetMemberIds:
                - compute distance from center (leader or static point)
                - decide inside/outside
                - update groups/{groupId}/geofences/{memberId}
                - send FCM ONLY on first transition inside -> outside
    """

    phone_number = event.params["phoneNumber"]

    # If user doc is deleted: nothing to do
    if event.data.after is None:
        print(f"[INFO] user {phone_number} document deleted, skipping.")
        return

    after_doc = event.data.after
    after_data = after_doc.to_dict() or {}

    # 1) Read lastKnownLocation from AppUser
    last_loc = after_data.get("lastKnownLocation")
    if not last_loc:
        print(f"[INFO] user {phone_number} has no lastKnownLocation, skipping.")
        return

    member_lat = last_loc.get("latitude")
    member_lng = last_loc.get("longitude")
    if member_lat is None or member_lng is None:
        print(f"[WARN] user {phone_number} missing latitude/longitude, skipping.")
        return

    member_lat = float(member_lat)
    member_lng = float(member_lng)
    print(f"[GEOFENCE] Processing user {phone_number} at ({member_lat}, {member_lng})")

    # 2) Find all groups where this user is a member
    groups_query = (
        db.collection("groups")
        .where("memberIds", "array_contains", phone_number)
        .stream()
    )

    now_iso = datetime.utcnow().isoformat()

    for group_doc in groups_query:
        group_id = group_doc.id
        group_data = group_doc.to_dict() or {}

        geofence_config = group_data.get("geofenceConfig")
        if not geofence_config:
            print(f"[INFO] group {group_id}: no geofenceConfig, skip.")
            continue

        # targetMemberIds is a list of phone numbers that are geofenced
        target_member_ids = geofence_config.get("targetMemberIds") or []
        if phone_number not in target_member_ids:
            print(f"[INFO] user {phone_number} not geofenced in group {group_id}.")
            continue

        g_type = geofence_config.get("type")
        radius_meters_raw = geofence_config.get("radiusInMeters")

        if radius_meters_raw is None:
            print(f"[ERROR] group {group_id}: radiusInMeters missing, skip.")
            continue

        radius_meters = float(radius_meters_raw)

        # 3) Determine geofence center
        if g_type == "dynamicLeader":
            # Center follows the live location of the group leader
            leader_id = group_data.get("leaderId")  # phoneNumber of leader
            if not leader_id:
                print(f"[ERROR] group {group_id}: dynamicLeader but no leaderId.")
                continue

            leader_snap = db.collection("users").document(str(leader_id)).get()
            leader_data = leader_snap.to_dict() or {}
            leader_loc = leader_data.get("lastKnownLocation")

            if not leader_loc:
                print(
                    f"[WARN] leader {leader_id} in group {group_id} "
                    f"has no lastKnownLocation."
                )
                continue

            center_lat = leader_loc.get("latitude")
            center_lng = leader_loc.get("longitude")
            if center_lat is None or center_lng is None:
                print(
                    f"[WARN] leader {leader_id} in group {group_id} "
                    f"missing latitude/longitude."
                )
                continue

            center_lat = float(center_lat)
            center_lng = float(center_lng)
        else:
            # Static center from geofenceConfig.staticLatitude / staticLongitude
            center_lat = geofence_config.get("staticLatitude")
            center_lng = geofence_config.get("staticLongitude")

            if center_lat is None or center_lng is None:
                print(
                    f"[ERROR] group {group_id}: staticLocation "
                    f"but staticLatitude/Longitude missing."
                )
                continue

            center_lat = float(center_lat)
            center_lng = float(center_lng)

        # 4) Compute distance and check inside/outside
        distance = haversine_distance(
            member_lat,
            member_lng,
            center_lat,
            center_lng,
        )
        is_outside = distance > radius_meters

        print(
            f"[DISTANCE] group={group_id}, user={phone_number}, "
            f"distance={distance:.2f}, radius={radius_meters}, "
            f"isOutside={is_outside}"
        )

        # 5) Read previous geofence status from groups/{groupId}/geofences/{memberId}
        geofence_ref = (
            db.collection("groups")
            .document(group_id)
            .collection("geofences")
            .document(phone_number)
        )

        prev_snap = geofence_ref.get()
        prev_data = prev_snap.to_dict() or {}
        was_outside = bool(prev_data.get("isOutsideGeofence", False))

        # First time crossing from inside -> outside
        is_first_cross = (not was_outside) and is_outside
        if is_first_cross:
            crossed_at = now_iso
            send_geofence_alert_fcm(group_id, phone_number, distance)

        # 6) Write updated status document (compatible with MemberGeofence model)
        geofence_ref.set(
            {
                "groupId": group_id,
                "memberId": phone_number,
                "isOutsideGeofence": is_outside,
                "updatedAt": now_iso,       # matches MemberGeofence.updatedAt
                "distanceMeters": distance, # matches MemberGeofence.distanceMeters
            },
            merge=True,
        )
