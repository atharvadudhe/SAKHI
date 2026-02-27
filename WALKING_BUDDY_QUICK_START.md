# Walking Buddy Broadcast Testing - Quick Start

## One-Time Setup

```bash
# 1. Install Firebase CLI
npm install -g firebase-tools

# 2. Login to Firebase
firebase login

# 3. Set your project
firebase use your-project-id
```

## Running Two Emulators (User + Volunteer)

### Step 1: Start Firebase Emulators (Terminal A)

```bash
cd /path/to/SAKHI
firebase emulators:start --project=your-project-id
```

Should see:
```
✔  Emulator Hub running on 127.0.0.1:4400
✔  Auth emulator running on http://127.0.0.1:9099
✔  Firestore emulator running on 127.0.0.1:8080
```

### Step 2A: Run User Emulator (Terminal B)

```bash
cd /path/to/SAKHI
flutter run
```

Or for iOS:
```bash
flutter run -d "iPhone 15"
```

### Step 2B: Run Volunteer Emulator (Terminal C)

```bash
cd /path/to/SAKHI
flutter run -d emulator-id-2
```

For Mac simulator:
```bash
open -a Simulator  # Opens default iOS simulator
# Then in VS Code: Ctrl+F5 to select device
```

## Testing Workflow

### User Emulator Steps:

1. **Sign up/Login** with email (e.g., user@test.com)
2. Open **Walking Buddy** screen
3. Tap **"Create Request"** button
4. **Set location** (auto or manual)
5. See **"Waiting for volunteer..."**
6. **Watch logs** for:
   - `🚶 Creating new broadcast request`
   - `✅ Request created successfully: <id>`

### Volunteer Emulator Steps:

1. **Sign up/Login** with DIFFERENT email (e.g., volunteer@test.com)
2. Go to **Volunteer Mode** screen
3. **Volunteer screen shows:**
   - "Initializing..."
   - Then request card(s) appear
4. If NOT seeing requests:
   - Tap **"Test Firestore Connection"** button
   - Check debug logs at bottom
5. Tap **"Accept Request"** when request appears

### Expected Timeline:

```
Time    User Emulator          Volunteer Emulator
T+0s    Creates request
T+0.5s  ✅ Request created
T+1s                          Stream connects
T+1.5s                        ✅ Snapshot: 1 pending request
T+2s                          Request card appears
T+3s    Taps accept
T+3.5s                        ✅ Request accepted
T+4s    ✅ Volunteer accepted  
T+5s    Live tracking appears   Live tracking appears
```

## Debug Panel in Volunteer Screen

The volunteer mode screen has a **built-in debug console**:

- Click `[×]` button in top-right to toggle
- Shows real-time logs of stream events
- Shows Firestore snapshot states
- **"Fetch All"** button: tests if collection is accessible
- **"Clear"** button: clears log history

### Interpreting Debug Logs:

```
⏳ Stream state: connecting...      → Connection starting
📊 Stream snapshot: 1 pending...    → Received data
❌ Stream error: Permission denied  → Security rule issue
📍 Location obtained: lat, lng      → Location working
✅ Request accepted                 → Accept succeeded
```

## Clearing Test Data

### Clear One Emulator's Data:

```bash
# Android
adb shell pm clear com.example.sakhi

# iOS
Simulator > Device > Erase All Content and Settings...
```

### Clear Firebase Emulator Data:

```bash
# Ctrl+C to stop firebase emulators:start
# Data auto-clears next time you start it
# For clean slate:
rm -rf ~/.cache/firebase/emulators 
# Then restart: firebase emulators:start
```

## Common Issues & Quick Fixes

### Volunteer sees nothing

1. **Check logs:**
   ```
   🎬 [VolunteerMode] Volunteer Mode Screen initialized
   ```
   
2. **Tap "Test Firestore Connection"** in debug panel

3. **Verify security rules:**
   - `firestore.rules` has walkingRequests collection
   - `allow read: if isAuthenticated();`

4. **Restart everything:**
   ```bash
   # Kill flutter runs (Ctrl+C)
   # Kill firebase (Ctrl+C)
   # Delete emulator data:
   rm -rf ~/.cache/firebase/emulators
   # Restart firebase and flutter
   ```

### Security Rules Error

Error message: `Permission denied on resource 'projects/.../firestore/...`

**Fix:**
1. Check `firestore.rules` file
2. Ensure walkingRequests collection section exists
3. Deploy rules: `firebase deploy --only firestore:rules`
4. Restart emulator

### Different Firebase Projects

If running on different machines:

```bash
# Verify same project
firebase use

# Or set explicitly
firebase use your-project-id
```

## Useful Commands

```bash
# Watch logs in Firebase emulator
firebase emulators:start --inspect-functions

# See all emulator activities
tail -f ~/.cache/firebase/emulators.log

# Reset specific collection
firebase shell  # Then: db.collection('walkingRequests').doc('<id>').delete()

# Export data (before deploy)
firebase firestore:export ./backups/export-date

# Import data
firebase firestore:import ./backups/export-date
```

## Production Testing

Before deploying to production:

1. **Deploy security rules:**
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **Test on real devices with live Firebase**

3. **Monitor usage:**
   ```bash
   firebase firestore:usage-report
   ```

4. **Check indices created:**
   - Go to Firestore console
   - Verify status=pending + createdAt index exists

---

**Still having issues?** Check [WALKING_BUDDY_DEBUG_GUIDE.md](WALKING_BUDDY_DEBUG_GUIDE.md) for comprehensive debugging steps!
