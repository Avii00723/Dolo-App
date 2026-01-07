# Ticket Detection Feature - Quick Testing Guide

## 🎯 Feature Overview
Users can now add and detect transport tickets (Train PNR, Flight Number, Bus Ticket) when sending trip requests for Train, Flight, or Bus transport modes.

---

## 🧪 How to Test

### Setup (No additional setup needed!)
- Feature is fully integrated and ready to test
- Uses mock data for demonstration
- All previous functionality remains intact

---

## 📋 Test Scenarios

### Test 1: Train PNR Detection ✅

**Steps:**
1. Search for available orders in SendPage
2. Select an order with **Transportation Mode: Train**
3. Click order to open SendTripRequestPage
4. Fill Vehicle Information (e.g., "Seat 42, Coach A1")
5. **New Section Appears: "Ticket Detection"**
6. Enter PNR: `1234567890`
7. Click "Detect Ticket"

**Expected Result:**
```
✅ Ticket Detected
Rajdhani Express 12001
Ticket/PNR: 1234567890
From: Delhi
To: Mumbai
Departure: 08:00 PM
Status: Confirmed
Info: Coach: A1, Seat: 42
```

**Mock Train Data Available:**
- `1234567890` → Rajdhani Express 12001 (Delhi→Mumbai)
- `1234567891` → Shatabdi Express 12002 (Bangalore→Chennai)
- `1234567892` → Local Express 21001 (Mumbai→Pune)

---

### Test 2: Flight Detection ✅

**Steps:**
1. Search for available orders
2. Select an order with **Transportation Mode: Plane/Flight**
3. Click order to open SendTripRequestPage
4. Fill Vehicle Information (e.g., "Seat 12A")
5. **New Section Appears: "Ticket Detection"**
6. Enter Flight Number: `6E 204` (or `6E204` without space)
7. Click "Detect Ticket"

**Expected Result:**
```
✅ Ticket Detected
IndiGo 6E 204
Ticket/PNR: 6E 204
From: Delhi (DEL)
To: Mumbai (BOM)
Departure: 09:00 AM
Status: Confirmed
Info: Terminal: 3
```

**Mock Flight Data Available:**
- `6E 204` → IndiGo, Delhi→Mumbai, 9:00 AM
- `AI 101` → Air India, Mumbai→Bangalore, 2:30 PM
- `SG 8741` → SpiceJet, Bangalore→Chennai, 11:15 AM
- `UK 221` → Vistara, Chennai→Hyderabad, 5:45 PM

---

### Test 3: Bus Ticket Detection ✅

**Steps:**
1. Search for available orders
2. Select an order with **Transportation Mode: Bus**
3. Click order to open SendTripRequestPage
4. Fill Vehicle Information (e.g., "Seat 22")
5. **New Section Appears: "Ticket Detection"**
6. Enter Ticket Number: `RB123456`
7. Click "Detect Ticket"

**Expected Result:**
```
✅ Ticket Detected
redBus Premium
Ticket/PNR: RB123456
From: Delhi
To: Agra
Departure: 11:00 PM
Status: Confirmed
Info: Type: Sleeper AC, Seats: S1, S2
```

**Mock Bus Data Available:**
- `RB123456` → redBus Premium (Delhi→Agra, Sleeper AC)
- `AB987654` → AbhiBus Travels (Mumbai→Pune, Volvo AC)
- `GR556789` → Goibibo Bus (Bangalore→Hyderabad, Semi-Sleeper)
- `MB334455` → MakeMyTrip Buses (Chennai→Tirupati, Seater)

---

### Test 4: Format Validation Error ❌

**Steps:**
1. Open ticket detection section for Train
2. Enter Invalid PNR: `12345` (only 5 digits, not 10)
3. Click "Detect Ticket"

**Expected Result:**
```
❌ Invalid PNR format. PNR should be 10 digits.
```

**Other Format Tests:**
- Train with `ABCD1234AB` → Error: "Invalid PNR format"
- Flight with `ABC123` → Error: "Invalid flight number format"
- Bus with `RB12` → Error: "Invalid ticket number format"

---

### Test 5: Unknown Ticket (Format Valid but Not in Mock Data)

**Steps:**
1. Open ticket detection for Train
2. Enter PNR: `9999999999` (valid format but not in mock data)
3. Click "Detect Ticket"

**Expected Result:**
```
✅ Ticket Detected (Generic Response)
Indian Railways
Ticket/PNR: 9999999999
Status: Confirmed
Info: PNR format valid. Please verify actual details separately.
```

---

### Test 6: Fill Entire Form with Ticket Info

**Steps:**
1. Complete entire form:
   - Vehicle Info: "Honda City, MH01AB1234"
   - Detect and confirm train ticket: `1234567890`
   - Comments: "Will pick up at station"
   - Departure: (from search)
   - Delivery: (from search)
2. Click "Send Request"

**Expected Result:**
```
✅ Request Sent Successfully!
Trip Request ID: #XXXXX
Submitted data includes:
  - transportTicketNo: "1234567890"
  - detectedTransportInfo: {transport details}
```

---

## 🔍 UI Flow Screenshots (Expected Behavior)

### Before Ticket Detection Section
```
[Vehicle Information Input]
↓
[Departure Date & Time] (Read-only)
↓
[Delivery Date & Time] (Read-only)
↓
[Comments]
↓
[Send Request Button]
```

### After Adding Ticket Detection Section (Train/Flight/Bus only)
```
[Vehicle Information Input]
↓
[🎫 TICKET DETECTION Section]
  ├─ Format hint
  ├─ [Ticket Number Input]
  └─ [Detect Ticket Button]
↓
[Detected Info Card] (appears after detection)
  ├─ ✅/❌ Status
  └─ [Transport Details]
↓
[Departure Date & Time] (Read-only)
↓
[Delivery Date & Time] (Read-only)
↓
[Comments]
↓
[Send Request Button]
```

---

## ⚙️ Technical Details for Developers

### File Structure
```
lib/
├── Controllers/
│   ├── TicketDetectionService.dart       ← NEW (All detection logic)
│   └── ... (existing)
├── Models/
│   ├── TripRequestModel.dart             ← MODIFIED (Added ticket fields)
│   └── ... (existing)
└── screens/
    └── send_page.dart                    ← MODIFIED (Added UI + logic)
```

### Key Classes
- `DetectedTransportInfo` - Data model for ticket info
- `TicketDetectionService` - Main service with methods:
  - `detectTicket()` - Main detection entry point
  - `_detectTrainPNR()` - Train-specific logic
  - `_detectFlightTicket()` - Flight-specific logic
  - `_detectBusTicket()` - Bus-specific logic
  - `validateTicketFormat()` - Format validation

### State Variables (in SendTripRequestPage)
```dart
final ticketNumberController = TextEditingController();
bool isDetectingTicket = false;  // Loading state
DetectedTransportInfo? detectedTransportInfo;  // Results
```

---

## 🎬 Console Output to Watch For

During detection, check Flutter console for debug messages:
```
🎫 Detecting ticket for Train: 1234567890
🚂 Detecting train PNR: 1234567890
✅ Detected Info: {transportType: Train, name: Rajdhani Express 12001, ...}

📤 Trip Request JSON: {transport_ticket_no: "1234567890", detected_transport_info: {...}}
```

---

## ❌ Common Test Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| No ticket section appears | Transport mode is not Train/Flight/Bus | Change order mode or create test order |
| Format error for valid ticket | Spacing issues (e.g., "6E204" vs "6E 204") | The system normalizes spacing |
| Detection takes too long | Simulated delay (800ms) is intentional | Wait for detection to complete |
| Detected info not showing | Invalid format | Check format hint, re-enter correctly |

---

## ✅ Validation Checklist

- [ ] Train PNR (10 digits) works with mock data
- [ ] Flight number (XX XXXX format) works with mock data
- [ ] Bus ticket (6-20 alphanumeric) works with mock data
- [ ] Format validation shows appropriate errors
- [ ] Detection button shows loading state
- [ ] Detected info displays in card
- [ ] Form submits with ticket info included
- [ ] Previous functionality (vehicle, comments, etc.) still works
- [ ] Mobile/tablet UI responsive
- [ ] No console errors

---

## 📝 Notes

- **Mock Data Only**: Uses simulated responses, not real APIs
- **No Backend Changes**: Ticket fields are optional for initial testing
- **Future APIs**: Ready to integrate real services (RailYatri, AviationStack, redBus)
- **Backward Compatible**: All existing features work unchanged

---

## 🚀 Next Steps

1. **Verify all test scenarios pass**
2. **Test on different devices/screen sizes**
3. **Check console for errors**
4. **Prepare mock data for production scenarios**
5. **Schedule API integration planning session**

---

