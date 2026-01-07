# Transport Ticket Detection Feature - Implementation Guide

## Overview
This feature enables users to add and detect transport tickets (Train PNR, Flight Number, Bus Ticket) when sending trip requests for Train, Flight, or Bus transport modes. The system validates ticket formats and attempts to fetch transport details using mock APIs that simulate real transport data providers.

---

## What's New

### 1. **Model Extension** - `TripRequestModel.dart`
The `TripRequestSendRequest` class now includes two new optional fields:
- `transportTicketNo`: The ticket/PNR number entered by the user
- `detectedTransportInfo`: Detected transport information in JSON format

```dart
final String? transportTicketNo;          // Ticket/PNR number
final String? detectedTransportInfo;      // Detected info from ticket
```

### 2. **New Service** - `TicketDetectionService.dart`
A comprehensive service that provides:

#### Key Classes:
- **`DetectedTransportInfo`**: Data model for detected transport information
- **`TicketDetectionService`**: Main service with detection logic

#### Core Methods:
- `detectTicket()`: Main async method to detect and validate transport tickets
- `_detectTrainPNR()`: Train PNR validation and mock detection
- `_detectFlightTicket()`: Flight number/booking validation and mock detection
- `_detectBusTicket()`: Bus ticket validation and mock detection
- `validateTicketFormat()`: Format validation for each transport type

#### Supported Transport Types & Formats:

**Train:**
- Format: 10 digits (PNR)
- Example: `1234567890`
- Mock data includes: Train name, departure/arrival points, time, coach, seat

**Flight:**
- Formats: 
  - `XX XXXX` (e.g., `6E 204`)
  - `XXXXXXXX` (10-digit booking reference)
- Example: `6E 204`, `AI 101`
- Mock data includes: Airline, routes, terminal, status

**Bus:**
- Format: 6-20 alphanumeric characters
- Example: `RB123456`
- Mock data includes: Operator, routes, bus type, seats

### 3. **UI Changes** - `send_page.dart`

#### New SendTripRequestPage Features:

**A. Ticket Input Section (Conditional)**
- Only displays for Train, Flight, and Bus modes
- Includes:
  - Context-specific hint text
  - Transport-specific placeholder
  - Detection button with loading state
  - Format validation with user-friendly error messages

**B. Detection Feedback**
- Loading indicator during detection
- Success/error card showing:
  - Transport type and name
  - Ticket/PNR number
  - Departure and arrival points
  - Departure time
  - Status
  - Additional details (coach/seat, terminal, etc.)

**C. Form Submission**
- Ticket info is now included in trip request if provided
- Detected transport information is serialized and sent to backend

---

## How to Use

### User Workflow:

1. **Navigate to Send Trip Request**
   - User searches for available orders and selects one
   - Clicks on an order to open `SendTripRequestPage`

2. **Fill Vehicle Information**
   - Enter vehicle details (e.g., Honda City, Registration number)

3. **For Transport Modes (Train/Flight/Bus)**
   - New ticket detection section appears
   - User enters transport ticket number:
     - **Train**: 10-digit PNR
     - **Flight**: Flight number (6E 204) or booking ID
     - **Bus**: Ticket number (RB123456)
   - Click **"Detect Ticket"** button

4. **View Detection Results**
   - System validates format
   - Fetches mock transport details
   - Displays detected information in a card
   - User can see confirmed details

5. **Submit Request**
   - Click **"Send Request"** to submit
   - Trip request includes ticket number and detected info

---

## Testing with Mock Data

### Pre-configured Mock Tickets:

#### Train PNR (Indian Railways Mock Data):
```
PNR: 1234567890 → Rajdhani Express 12001, Delhi→Mumbai, 8:00 PM
PNR: 1234567891 → Shatabdi Express 12002, Bangalore→Chennai, 6:30 AM
PNR: 1234567892 → Local Express 21001, Mumbai→Pune, 4:15 PM
```

#### Flight Numbers (Indian Domestic Airlines):
```
6E 204  → IndiGo, Delhi→Mumbai, 9:00 AM, Terminal 3
AI 101  → Air India, Mumbai→Bangalore, 2:30 PM, Terminal 2
SG 8741 → SpiceJet, Bangalore→Chennai, 11:15 AM, Terminal 1
UK 221  → Vistara, Chennai→Hyderabad, 5:45 PM, Terminal 1
```

#### Bus Tickets (Indian Bus Operators):
```
RB123456 → redBus Premium, Delhi→Agra, 11:00 PM, Sleeper AC
AB987654 → AbhiBus Travels, Mumbai→Pune, 6:00 PM, Volvo AC
GR556789 → Goibibo Bus, Bangalore→Hyderabad, 10:30 PM, Semi-Sleeper
MB334455 → MakeMyTrip Buses, Chennai→Tirupati, 5:45 AM, Seater
```

### Quick Test Steps:

1. **Test Train Detection:**
   - Order with transport mode: "Train"
   - Enter PNR: `1234567890`
   - Expected: Shows "Rajdhani Express 12001" with full details

2. **Test Flight Detection:**
   - Order with transport mode: "Plane"
   - Enter Flight: `6E 204`
   - Expected: Shows "IndiGo 6E 204" with terminal and status

3. **Test Bus Detection:**
   - Order with transport mode: "Bus"
   - Enter Ticket: `RB123456`
   - Expected: Shows "redBus Premium" with route and bus type

4. **Test Format Validation:**
   - Enter invalid formats (e.g., `12345` for train)
   - Expected: Shows format-specific error message

---

## Technical Details

### Service Architecture:

```
TicketDetectionService
├── detectTicket(vehicleType, ticketNo, date)
│   ├── Validates format
│   ├── Routes to type-specific detector
│   └── Returns DetectedTransportInfo
│
├── _detectTrainPNR(pnr, date)
│   ├── Format: 10 digits
│   ├── Mock API simulation
│   └── Returns train details
│
├── _detectFlightTicket(ticketNo, date)
│   ├── Format: XX XXXX or 10-digit
│   ├── Mock API simulation
│   └── Returns flight details
│
├── _detectBusTicket(ticketNo, date)
│   ├── Format: 6-20 alphanumeric
│   ├── Mock API simulation
│   └── Returns bus details
│
└── validateTicketFormat(vehicleType, ticketNo)
    └── Regex-based format validation
```

### Data Flow:

```
User Input (Ticket Number)
       ↓
Format Validation
       ↓
API Call (Simulated)
       ↓
DetectedTransportInfo
       ↓
UI Display
       ↓
Trip Request Submission
       ↓
Backend Receives: 
  - transportTicketNo
  - detectedTransportInfo (JSON)
```

---

## Migration to Real APIs

### For Production Deployment:

#### Train PNR Detection:
Replace `_detectTrainPNR()` with real API call:
```dart
// Option 1: RailYatri API
final url = 'https://api.railtimi.com/pnr/status/$pnr';

// Option 2: ConfirmTkt API
final url = 'https://www.confirmtkt.com/api/v1/pnr/status';

// Option 3: Railway API
final url = 'https://railwayapi.herokuapp.com/api/v2/pnrStatus/$pnr';
```

#### Flight Details:
Replace `_detectFlightTicket()` with real API call:
```dart
// Option 1: AviationStack
final url = 'https://api.aviationstack.com/v1/flights?flight_iata=$flightNumber';

// Option 2: FlightAware AeroAPI
final url = 'https://aeroapi.flightaware.com/aeroapi/flights/$flightNumber';

// Partnership APIs: Goibibo, MakeMyTrip, etc.
```

#### Bus Ticket Details:
Replace `_detectBusTicket()` with real API call:
```dart
// Option 1: redBus API (Partnership)
final url = 'https://api.redbus.com/api/v1/ticket/$ticketNo';

// Option 2: AbhiBus API
final url = 'https://api.abhibus.com/ticket/$ticketNo';
```

---

## Error Handling

The system provides user-friendly error messages:

```
Format Errors:
- "Invalid PNR format. PNR should be 10 digits."
- "Invalid flight number or booking reference. Use format: XX XXXX (e.g., 6E 204)"
- "Invalid ticket number. Bus ticket should be at least 6 characters."

Detection Errors:
- "Error detecting ticket: [error message]"

Success Messages:
- "✅ Train ticket detected: Rajdhani Express 12001"
- "✅ Flight ticket detected: IndiGo 6E 204"
- "✅ Bus ticket detected: redBus Premium"
```

---

## Files Modified/Created

### Created:
1. **`lib/Controllers/TicketDetectionService.dart`** (NEW)
   - Complete ticket detection service with mock data

### Modified:
1. **`lib/Models/TripRequestModel.dart`**
   - Added `transportTicketNo` field
   - Added `detectedTransportInfo` field
   - Updated `toJson()` method

2. **`lib/screens/send_page.dart`**
   - Added import for `TicketDetectionService`
   - Added state variables: `ticketNumberController`, `isDetectingTicket`, `detectedTransportInfo`
   - Added methods: `_detectTransportTicket()`, `_buildDetectedInfoCard()`, `_getTicketHint()`, `_getTicketPlaceholder()`
   - Updated `_submitRequest()` to include ticket info
   - Added conditional ticket detection section in UI
   - Updated disposal cleanup

---

## Features Preserved

✅ All existing functionality remains unchanged:
- Search available orders
- Route preview with map
- Stopover management
- Vehicle information input
- Comments section
- Departure and delivery date/time selection
- Form validation
- Success feedback
- Navigation flow

---

## Future Enhancements

1. **Real API Integration**: Replace mock data with live API calls
2. **Offline Validation**: Cache ticket data for offline lookup
3. **Multiple Tickets**: Support multiple tickets per trip
4. **Ticket History**: Store and reuse recently entered tickets
5. **Smart Detection**: ML-based format recognition
6. **Real-time Updates**: Live tracking of train/flight/bus status

---

## Support & Notes

- This is a **TESTING/DEMO** version with mock data
- Format validation works for all transport types
- Detection API calls are simulated with delays
- All previous functionality is fully preserved
- No backend changes required for initial testing (fields are optional)

---

