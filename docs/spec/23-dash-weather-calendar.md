# 23 — DDash, Weather & Calendar Specification (`DASH`)

## 0. Coverage Manifest
- `quickshell/Modules/DDash/DDashPopout.qml` — Dedicated popout surface host, multi-monitor anchor management, edge placement, and open/close state transitions.
- `quickshell/Modules/DDash/DashTabHost.qml` — Master tab bar host switching between 6 primary dash views: Overview, Media, Weather, Wallpaper, Wellbeing, and Notifications.
- `quickshell/Modules/DDash/DashMetrics.qml` — Dimensional metrics, card sizing units (`gridRowUnit`, `gridGap`), and typography scales.
- `quickshell/Modules/DDash/DashRegistry.qml` — Central card catalog defining available overview widgets, default layouts, and category groupings.
- `quickshell/Modules/DDash/DashPageTitle.qml` & `DashPageActions.qml` — Standardized top header bar with title label and action buttons.
- `quickshell/Modules/DDash/DashSheetHandle.qml` — Touch and mouse drag handle for sheet sliding gestures.
- `quickshell/Modules/DDash/OverviewTab.qml` — Primary dashboard view hosting the bin-packed `DashCardGrid`.
- `quickshell/Modules/DDash/Overview/DashCardGrid.qml` — 2D bin-packed card grid (`DEditableGrid`) with interactive drag reordering and resizing.
- `quickshell/Modules/DDash/Overview/DashCardSlot.qml` — Card slot delegate providing selection borders, drag placeholders, and delete badges.
- `quickshell/Modules/DDash/Overview/DashEditChrome.qml` & `DashEditControls.qml` — Floating toolbar during dash customization mode (Add Card, Reset, Done).
- `quickshell/Modules/DDash/Overview/DashOptionsSheet.qml` & `DashOptionRow.qml` — Slide-in inspector for configuring individual card properties.
- `quickshell/Modules/DDash/Overview/Card.qml` — Base card container with M3 surface tone styling, border highlights, and focus traversal.
- `quickshell/Modules/DDash/Overview/ClockCard.qml` — Digital/analog clock card with date, timezone display, and alarm indicators.
- `quickshell/Modules/DDash/Overview/UserInfoCard.qml` — User profile card with avatar, username, hostname, and OS uptime.
- `quickshell/Modules/DDash/Overview/CalendarOverviewCard.qml` (860 lines) — Interactive month calendar grid, ISO week numbering, event dots, and day detail view.
- `quickshell/Modules/DDash/Overview/CalendarEventDetail.qml` & `CalendarEventEditor.qml` — Event inspection and creation modal dialogs.
- `quickshell/Modules/DDash/Overview/WeatherOverviewCard.qml` — Compact current weather snapshot with condition icon, temperature, and hourly preview.
- `quickshell/Modules/DDash/Overview/MediaOverviewCard.qml` — Compact MPRIS media card with album thumbnail, track info, and playback buttons.
- `quickshell/Modules/DDash/Overview/WellbeingOverviewCard.qml` — Daily screen time gauge, top 3 used applications, and limit alerts.
- `quickshell/Modules/DDash/Overview/NotificationsOverviewCard.qml` — Recent unread notifications summary.
- `quickshell/Modules/DDash/Overview/SystemMonitorCard.qml`, `CpuCard.qml`, `MemoryCard.qml`, `DiskCard.qml`, `NetworkCard.qml`, `BatteryCard.qml`, `MetricCard.qml`, `MetricGauge.qml` — Hardware resource cards with live utilization graphs and radial gauges.
- `quickshell/Modules/DDash/MediaPlayerTab.qml` — Full-bleed media hub supporting Bento and Material layouts.
- `quickshell/Modules/DDash/Media/*` (19 files) — `LyricsOverlay.qml`, `LyricsVocal.qml`, `MediaArtSurface.qml`, `MediaVolumeWheel.qml`, `MediaSinkWheel.qml`, `MediaSeekbar.qml`, `MediaTransport.qml`, `BentoChrome.qml`, `MaterialChrome.qml`, etc.
- `quickshell/Modules/DDash/WeatherTab.qml` — Comprehensive weather dashboard view.
- `quickshell/Modules/DDash/Weather/WeatherHero.qml` — Large hero card showing current temperature, feels-like, city, condition description, and high/low temps.
- `quickshell/Modules/DDash/Weather/WeatherSky.qml` (205 lines) — Dynamic celestial arc visualizing sun/moon position, daylight progress, sunrise/sunset, and moon phases.
- `quickshell/Modules/DDash/Weather/WeatherForecastChart.qml` — Smooth Bezier curve temperature graph over the next 24 hours.
- `quickshell/Modules/DDash/Weather/WeatherForecastCard.qml` — 7-day weather forecast list with rain probability and min/max bars.
- `quickshell/Modules/DDash/Weather/WeatherMetricCard.qml` — Sensor cards for UV index, wind speed/direction, humidity, barometric pressure, and visibility.
- `quickshell/Modules/DDash/Weather/WeatherVisuals.js` — Color gradient generator matching weather codes and solar elevation.
- `quickshell/Modules/DDash/WallpaperTab.qml` & `WallpaperCarousel.qml` — Wallpaper browser grid and horizontal carousel with tag filters.
- `quickshell/Modules/DDash/WellbeingTab.qml` — Detailed screen time analytics dashboard.
- `quickshell/Modules/DDash/Wellbeing/WeeklyChart.qml` — Bar chart comparing screen time across 7 days of the week.
- `quickshell/Modules/DDash/Wellbeing/AppUsageList.qml` — Ranked list of application screen time with app icons and percentages.
- `quickshell/Modules/DDash/Wellbeing/AppLimitSheet.qml` & `DurationSteppers.qml` — Modal sheet for setting daily usage limits per application.
- `quickshell/Modules/DDash/Wellbeing/Wellbeing.js` (143 lines) — Screen time database engine with 92-day retention (`retentionDays = 92`), week-start normalization, and app total aggregation.
- `quickshell/Modules/DDash/NotificationsTab.qml` — Notification center view with history list, app grouping, and clear-all actions.
- `quickshell/Services/WeatherService.qml` (1,131 lines) — Weather service with Open-Meteo API integration, geocoding, WMO weather interpretation, and SunCalc celestial calculations.
- `quickshell/Services/CalendarService.qml`, `CalendarDankBackend.qml`, `CalendarKhalBackend.qml` — Calendar service layer integrating local events, khal, and CalDAV backends.

---

## 1. Purpose & User-Visible Behavior
DDash is an expansive, tabbed desktop dashboard overlay designed for ambient monitoring, deep media interaction, weather forecasting, digital wellbeing tracking, and calendar scheduling.

Key user-visible behaviors include:
1. **Multi-Tab Architecture**: Users can switch seamlessly between 6 dedicated tabs:
   - **Overview**: Customizable grid of widget cards.
   - **Media Player**: Fullscreen media experience with synchronized lyrics and audio sink wheel.
   - **Weather**: Complete meteorological station with celestial sky arc and 7-day forecast.
   - **Wallpapers**: Visual carousel of local wallpapers with live preview.
   - **Wellbeing**: Screen time tracking, daily limits, and weekly usage graphs.
   - **Notifications**: Historical notification log grouped by application.
2. **Interactive Calendar & Event Scheduling**:
   - Month view with ISO week numbers and configurable first day of week.
   - Colored event indicator dots beneath calendar days.
   - Day agenda view displaying scheduled events.
   - Event creation dialog (`CalendarEventEditor`) allowing adding and modifying events with reminders.
3. **Meteorological Station (Weather Engine)**:
   - Real-time weather fetched via Open-Meteo geocoding and forecast APIs (no API key required).
   - Celestial Sky Arc (`WeatherSky`): Real-time parabolic/quad arc tracing the sun or moon across the horizon using exact astronomical coordinates (`SunCalc`).
   - 24-hour hourly forecast temperature curve with rain probability bars.
   - 7-day weather forecast with high/low bars and WMO condition icons.
   - Metric cards: UV index, Wind speed/direction, Humidity, Atmospheric pressure, Visibility.
4. **Digital Wellbeing & Screen Time**:
   - Automatic background tracking of active foreground window time.
   - 92-day local history retention without external analytics.
   - Weekly usage bar chart highlighting daily trends.
   - App limits: Users can set daily duration quotas (e.g. 1h 30m for a browser); reaching the quota emits notifications and highlights the app in red.
5. **Full-Bleed Media Center**:
   - Supports both `bento` and `material` chrome layouts.
   - Synchronized LRC lyrics overlay with singing vocal line animations.
   - Audio sink routing wheel to quickly redirect sound to headphones, speakers, or external monitors.

---

## 2. Architecture & Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ DDashPopout.qml (Top / Center Overlay Panel)                               │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ DashTabHost.qml                                                       │  │
│  │ [ Overview | Media Player | Weather | Wallpaper | Wellbeing | Alerts ]│  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
│                                      │                                      │
│         ┌────────────────────────────┼───────────────────────────┐          │
│         ▼                            ▼                           ▼          │
│  ┌──────────────┐             ┌──────────────┐            ┌──────────────┐  │
│  │ OverviewTab  │             │  WeatherTab  │            │ WellbeingTab │  │
│  │              │             │              │            │              │  │
│  │ DashCardGrid │             │ WeatherHero  │            │ WeeklyChart  │  │
│  │  ├─ Clock    │             │ WeatherSky   │            │ AppUsageList │  │
│  │  ├─ Calendar │◄──Calendar  │  (Celestial) │◄──Weather  │ AppLimits    │  │
│  │  ├─ Media    │   Service   │ ForecastChart│   Service  │  (92d store) │  │
│  │  ├─ Hardware │             │ 7-Day List   │  (Open-    │              │  │
│  │  └─ Wellbeing│             │ Metric Cards │   Meteo)   │              │  │
│  └──────────────┘             └──────────────┘            └──────────────┘  │
│         │                            │                           │          │
│         ▼                            ▼                           ▼          │
│  ┌──────────────┐             ┌──────────────┐            ┌──────────────┐  │
│  │MediaPlayerTab│             │ WallpaperTab │            │Notifications │  │
│  │ Bento/Mat.   │             │ Carousel     │            │ History List │  │
│  │ LyricsVocal  │             │ Tag Filters  │            │ Grouped Apps │  │
│  │ SinkWheel    │             │ Fast Apply   │            │ Clear All    │  │
│  └──────────────┘             └──────────────┘            └──────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Requirements

### Tab Navigation & Host (`DASH-TAB`)
- `DASH-TAB-001`: `DashTabHost` must provide navigation between 6 distinct views:
  1. `overview` (OverviewTab)
  2. `media` (MediaPlayerTab)
  3. `weather` (WeatherTab)
  4. `wallpaper` (WallpaperTab)
  5. `wellbeing` (WellbeingTab)
  6. `notifications` (NotificationsTab)
- `DASH-TAB-002`: Switching tabs must use smooth horizontal slide or fade transitions with focus retention.
- `DASH-TAB-003`: Opening DDash via shortcut or IPC must allow specifying an initial target tab (e.g. `dms dash open --tab weather`).

### Calendar Engine (`DASH-CAL`)
- `DASH-CAL-001`: The calendar grid must display standard 7-column month layouts with configurable `firstDayOfWeek` (0 = Sunday to 6 = Saturday, default matches system locale).
- `DASH-CAL-002`: ISO 8601 week numbers must be calculated dynamically (`getWeekNumber`) and displayed in a dedicated leading column when enabled.
- `DASH-CAL-003`: Days with scheduled events must display colored indicator dots beneath the day number, matching the event category or primary theme color.
- `DASH-CAL-004`: Clicking any day selects that date and loads its event agenda list (`updateSelectedDateEvents`).
- `DASH-CAL-005`: Navigating months forward/backward must query `CalendarService.loadEvents(startDate, endDate)` covering the visible date range plus 7-day padding.
- `DASH-CAL-006`: Event editor dialog (`CalendarEventEditor`) must support entering title, start time, end time, location, reminder trigger, and calendar destination.

### Weather & Celestial Sky Engine (`DASH-WEATH`)
- `DASH-WEATH-001`: Weather information must be fetched from Open-Meteo (`https://api.open-meteo.com/v1/forecast`) with automatic coordinates resolution via geocoding API.
- `DASH-WEATH-002`: The weather update interval must default to 15 minutes (900,000 ms), with exponential retry backoff on failure (max 3 retries).
- `DASH-WEATH-003`: WMO weather codes (0 to 99) must map accurately to translated condition strings and contextual day/night Material symbols (e.g. `clear_day` vs `clear_night`, `thunderstorm`, `snowing_heavy`).
- `DASH-WEATH-004` (Celestial Sky Arc):
  - `WeatherSky.qml` must compute exact solar and lunar positions using `SunCalc` based on latitude, longitude, and elevation.
  - The solar arc must render a parabolic curve (`PathQuad` from $x=0, y=h$ to $x=w, y=h$ with control point at $x=\frac{w}{2}, y=0$).
  - Day progress $P_{\text{day}} = \frac{T_{\text{now}} - T_{\text{sunrise}}}{T_{\text{sunset}} - T_{\text{sunrise}}}$ must smoothly position the sun orb along the path.
  - When night falls, the widget switches to lunar mode, rendering the moon track altitude curve and current moon phase icon (from 8 distinct phases: `moon_new`, `moon_waxing_crescent`, `moon_first_quarter`, `moon_waxing_gibbous`, `moon_full`, `moon_waning_gibbous`, `moon_last_quarter`, `moon_waning_crescent`).
- `DASH-WEATH-005`: Hourly temperature forecast chart must render a smooth cubic Bezier curve connecting 24 hourly data points with precipitation probability bars along the x-axis.

### Digital Wellbeing & Usage Limits (`DASH-WELL`)
- `DASH-WELL-001`: `Wellbeing.js` must record active foreground window duration per application bundle/appId in local storage.
- `DASH-WELL-002`: Usage data must be retained for exactly 92 days (`retentionDays = 92`), automatically pruning entries older than 3 months.
- `DASH-WELL-003`: The weekly chart (`WeeklyChart.qml`) must render a 7-day comparative bar graph indicating daily screen time in hours and minutes, highlighting the current day.
- `DASH-WELL-004`: Users can set daily duration quotas per application via `AppLimitSheet.qml`.
- `DASH-WELL-005`: When an application exceeds 90% and 100% of its daily limit, a system notification must be dispatched, and the application's card in DDash must display an overdue warning badge.

### Full-Bleed Media Center (`DASH-MED`)
- `DASH-MED-001`: MediaPlayerTab must support two distinct presentation layouts: `bento` (multi-tile card grid) and `material` (expressive centered album art with floating controls).
- `DASH-MED-002`: Lyrics overlay (`LyricsOverlay.qml`) must display synchronized scrolling lyrics parsed from LRC format, with animated vocal emphasis on the currently singing line (`LyricsVocal.qml`).
- `DASH-MED-003`: An interactive audio sink wheel (`MediaSinkWheel.qml`) must allow flicking or clicking to route playback to alternative output devices.
- `DASH-MED-004`: Seeking along the timeline must update track position using zero-idle MPRIS position interpolation.

---

## 4. Settings Keys
DDash settings are managed under `SettingsData`:

| Key | Type | Default | Description |
|---|---|---|---|
| `dashDefaultTab` | `string` | `"overview"` | Default tab opened on activation |
| `dashCards` | `array` | Default Card Array | Card layout configuration for Overview tab |
| `weatherProvider` | `string` | `"open-meteo"` | Weather backend provider |
| `weatherLatitude` | `real` | `0.0` | Custom override latitude |
| `weatherLongitude` | `real` | `0.0` | Custom override longitude |
| `weatherCity` | `string` | `""` | Configured city name |
| `weatherUnits` | `string` | `"metric"` | `"metric"` (°C, km/h) or `"imperial"` (°F, mph) |
| `calendarFirstDayOfWeek`| `int` | `-1` | First day of week (-1 = system locale, 0 = Sun, 1 = Mon) |
| `calendarShowWeekNumbers`| `bool` | `false` | Show ISO week numbers in calendar |
| `wellbeingEnabled` | `bool` | `true` | Enable foreground app screen time tracking |
| `wellbeingLimits` | `object` | `{}` | Map of `appId -> limitSeconds` daily quotas |
| `mediaPlayerLayout` | `string` | `"bento"` | Layout style: `"bento"` or `"material"` |

---

## 5. IPC/CLI API
| Method | Arguments | Returns | Description |
|---|---|---|---|
| `dash.toggle` | `[tab?: string]` | `bool` | Toggles DDash visibility |
| `dash.openTab` | `tab: string` | `void` | Opens DDash directly on specified tab |
| `dash.close` | `none` | `void` | Closes DDash popout |
| `weather.refresh` | `none` | `void` | Forces immediate meteorological data reload |
| `weather.setCity` | `city: string` | `bool` | Geocodes and updates location coordinates |
| `calendar.createEvent` | `eventData: object` | `string` | Creates new calendar appointment |
| `wellbeing.getReport`| `period: "day"|"week"`| `object` | Returns aggregated screen time metrics |
| `wellbeing.setLimit` | `appId: string, seconds: int` | `void` | Configures daily screen time limit |

---

## 6. macOS Mapping
- **Overlay Window**:
  - `DDashPopout` maps to an `NSPanel` with `.popUpMenu` or `.floating` level, centered on the active display.
- **Weather Engine**:
  - Direct integration with Open-Meteo REST API using `URLSession`.
  - Solar calculations using Swift port of `SunCalc` or CoreLocation astronomical equations.
  - CoreLocation `CLLocationManager` for automatic coordinate detection when allowed.
- **Calendar Engine**:
  - `EventKit` (`EKEventStore`) integration for native macOS Calendar events (iCloud, Google Calendar, Exchange).
  - Querying events via `events(matching: predicate)` and creating events via `EKEvent`.
- **Digital Wellbeing / Screen Time**:
  - Track active application focus via `NSWorkspace.shared.frontmostApplication` and `NSWorkspace.didActivateApplicationNotification`.
  - Maintain 92-day SQLite or CoreData database recording active foreground duration per bundle identifier.
  - Post notifications via `UNUserNotificationCenter` when quotas are exceeded.

---

## 7. Port Audit
| File / Feature in Upstream | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `DDashPopout.qml` & 6-Tab Host | Missing | **Absent** | Port has NO multi-tab DDash dashboard overlay. Only a partial `CalendarView` exists. |
| Weather Engine & Celestial Arc (`WeatherSky`) | Missing | **Absent** | Port has no weather tab, no Open-Meteo integration, no solar/lunar position math, and no celestial sky arc. |
| Calendar Engine & Event Editor (`CalendarOverviewCard`) | Partially Insp. | **Major Gap** | Port has a simple month view in SwiftUI but lacks ISO week numbers, EventKit / CalDAV loading, event indicator dots, and event editor modal. |
| Digital Wellbeing & Limits (`WellbeingTab.qml`) | Missing | **Absent** | Port has zero screen time tracking, no 92-day local history database, and no app duration limiters. |
| Full-Bleed Media Center (`MediaPlayerTab.qml`) | Missing | **Absent** | Port lacks large media hub with Bento/Material layouts, lyrics vocals, and audio sink routing wheel. |
| Wallpaper Carousel (`WallpaperTab.qml`) | Missing | **Absent** | Port has no wallpaper carousel or browser tab in dash. |

---

## 8. Reimplementation Checklist
- [ ] Create `DDashPopout` overlay panel supporting 6 tabbed views with keyboard shortcuts.
- [ ] Implement `WeatherService` with Open-Meteo API, geocoding, and astronomical solar/lunar equations.
- [ ] Build `WeatherSky` celestial arc with real-time sun/moon trajectory rendering and moon phase icons.
- [ ] Implement `CalendarService` with `EventKit` integration for bidirectional macOS Calendar sync.
- [ ] Build `CalendarOverviewCard` with ISO week numbers, date selection, agenda list, and event editor dialog.
- [ ] Implement `WellbeingService` with active app focus tracking, 92-day SQLite storage, weekly charts, and quota alerts.
- [ ] Build `MediaPlayerTab` featuring Bento and Material chrome, synchronized LRC lyrics, and output device wheel.
- [ ] Add Wallpaper browsing and preview tab with instant wallpaper switcher.
