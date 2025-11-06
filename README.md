# Sheap Project | مشروع شِعاب

A real-time navigation and safety app for pilgrims in the Holy Mosques to ensure peace of mind and group safety.

## 🎯 Project Goal

Sheap aims to solve the problem of getting lost and anxiety for visitors to Makkah and Madinah, especially for families and the elderly, through a precise and reliable tracking and navigation system that works even in the most challenging conditions (extreme crowds and network outages).

## ✨ Core Features

* **Real-Time Group Tracking:** Track family or group members on the map in real-time using the MQTT protocol.

* **Offline-First Navigation:** Download a "Haram Map Package" (including important POIs) for use without any internet connection.

* **Multi-Floor Indoor Maps:** Custom maps for each floor (Mataf, Ground, First, Roof) with a manual floor selector button.

* **Geofencing / Safe Zones:** Group admins can draw a "Safe Zone" and receive an instant alert if any member leaves it.

* **AR Navigation:** Display navigation arrows directly on the phone's camera feed.

* **Live Signboard Translation:** Uses `ML Kit` directly on the device (no internet required).

* **SOS Alerts:** An emergency button to send an alert and location to all group members.

## 💻 Technology Stack

This project is built on a cloud-native, scalable infrastructure to serve millions of users.

| **Component** | **Technology Used** | 
| :--- | :--- |
| **Mobile App** | `Flutter` | 
| **Mapping** | `Mapbox` (for Offline & Indoor Maps) | 
| **Backend Logic** | `AWS Fargate` (Python / Java) | 
| **Real-Time** | `AWS IoT Core` (MQTT) | 
| **Geospatial DB** | `AWS RDS` (PostgreSQL + `PostGIS`) | 
| **Caching** | `AWS ElastiCache` (Redis) | 
| **Authentication** | `AWS Cognito` | 
| **AR Module** | `Unity (C#)` / `ML Kit` | 
| **Notifications** | `Amazon SNS` | 
| **Storage** | `Amazon S3` | 

*This repository contains the source code for the Shaab Project as part of the submission requirements.*
