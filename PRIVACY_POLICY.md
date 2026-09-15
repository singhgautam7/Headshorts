# Privacy Policy for Headshorts

**Last Updated:** September 15, 2026

**Developer:** Gautam Rajeev Singh  
**Application:** Headshorts — News Reader & Summarizer  

---

## 1. Overview & Core Philosophy

Headshorts is designed from the ground up to be **local-first, transparent, and privacy-respecting**. We believe reading the news should not involve tracking, surveillance, or personal data collection.

- **No Account Required:** You do not need to register, create a profile, or sign in to use Headshorts.
- **No Remote Application Servers:** Headshorts does not run backend servers, proprietary tracking databases, or intermediate proxy servers.
- **No Analytics, Tracking, or Ads:** Headshorts contains zero third-party advertising SDKs, analytics frameworks, tracking pixels, or telemetry beacons.

---

## 2. Information Handled by the App

### Local Storage on Your Device
All data generated or downloaded during your use of Headshorts is stored locally on your device in a private SQLite database (via Drift) and local device cache. This includes:
- Cached RSS headlines, snippets, and article text
- Cached article thumbnail images
- Your reading history and unread status
- Filter preferences (active sources, selected categories)
- Display preferences (theme selection, AMOLED pitch-black mode, dynamic color settings)

This data stays on your device and is never transmitted to any server managed by Headshorts.

### Data We Do NOT Collect
- We do not collect personally identifiable information (PII) such as your name, email address, phone number, or physical location.
- We do not monitor, log, or profile your reading habits or political preferences.
- We do not share or sell any device or user data to data brokers or third parties.

---

## 3. Network Usage & Device Permissions

Headshorts requests minimal permissions strictly necessary to function as a news reader:

| Permission | Purpose |
| :--- | :--- |
| `android.permission.INTERNET` | Used to directly fetch publicly available RSS/Atom feeds and article webpages from publishers (e.g., Finshots, The Economic Times, BBC, NDTV, TechCrunch) and display images. |
| `android.permission.ACCESS_NETWORK_STATE` | Used to check whether the device has an active internet connection before attempting network requests, avoiding unnecessary timeouts and saving battery. |

> **Direct Connections:** All network requests for news feeds, full articles, and images occur **directly** between your device and the respective publisher's web servers. Headshorts does not operate a proxy or intermediary server to intercept your requests.

---

## 4. Third-Party Links and External Content

- **Publisher Websites:** When you tap "Open in Web" or tap an external link, the destination webpage opens in your default web browser or an in-app custom tab directly on the publisher’s website. Those third-party websites operate under their own independent privacy policies and terms of service.
- **Sharing Content:** When you use the system share button, Headshorts passes the article title and URL directly to your device's native Android share sheet.

---

## 5. Data Control and Deletion

You have complete ownership and control over your data:
- **Cache Management:** You can clear cached data at any time from your device's application settings.
- **Complete Deletion:** Uninstalling Headshorts immediately and permanently deletes all locally stored database files, cached articles, images, and preferences from your device.

---

## 6. Children's Privacy

Headshorts does not knowingly collect or solicit personal information from children under the age of 13 (or under 16 in applicable jurisdictions).

---

## 7. Changes to This Privacy Policy

If this Privacy Policy is modified, the updated version will be published in this repository with a revised "Last Updated" date.

---

## 8. Contact Information

If you have questions, suggestions, or concerns regarding this Privacy Policy or Headshorts, please contact:

**Developer:** Gautam Rajeev Singh  
**Project:** Headshorts  
**Repository:** [https://github.com/singhgautam7/Headshorts](https://github.com/singhgautam7/Headshorts)
