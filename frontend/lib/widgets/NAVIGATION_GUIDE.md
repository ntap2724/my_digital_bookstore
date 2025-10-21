# Responsive Navigation System - Material Design 3

## 📱 Overview

The navigation system now supports **Material Design 3** with **responsive layouts**:

### Layouts by Screen Size

| Screen Size | Layout Type | Components Used |
|-------------|-------------|-----------------|
| **Mobile** (< 600dp) | Bottom Navigation + Drawer | `BottomNavigationBar` + `AppNavigationMenu` (Drawer) |
| **Tablet** (600-840dp) | Compact Navigation Rail | `NavigationRail` (collapsed, icons only) |
| **Desktop** (≥ 840dp) | Extended Navigation Rail | `NavigationRail` (expanded, icons + labels) |

---

## 🎨 Design Improvements

### 1. Header Redesign
- ✅ **Gradient background**: primaryContainer → primary
- ✅ **Double-circle avatar** with elevation
- ✅ **Better typography**: titleLarge (bold) for name, bodyMedium (70% opacity) for email
- ✅ **Improved spacing** and alignment

### 2. Menu Items - MD3 Style
- ✅ **Selected state**: `surfaceContainerHighest` background + **4dp left border** (primary color)
- ✅ **Filled icons** when selected (e.g., `Icons.home` instead of `Icons.home_outlined`)
- ✅ **Visual hierarchy**: Primary items use `labelLarge`, secondary use `bodyMedium`, admin uses primary color
- ✅ **Better dividers**: outlineVariant with horizontal indent

### 3. Color & Theming
- ✅ Uses **proper MD3 color tokens**
- ✅ **High contrast** for selected items
- ✅ Admin items use **primary color** for distinction
- ✅ Smooth transitions and ripple effects

---

## 🛠️ How to Use

### Option 1: Use ResponsiveNavigationWrapper (Recommended)

The simplest way to add responsive navigation to any page:

```dart
import 'package:my_flutter_app/widgets/responsive_navigation_wrapper.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveNavigationWrapper(
      currentRoute: '/my-page',
      appBar: AppBar(
        title: Text('My Page'),
      ),
      body: Center(
        child: Text('Page content here'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ),
    );
  }
}
```

### Option 2: Manual Layout (Advanced)

For custom layouts, use individual navigation widgets:

#### Mobile Layout:
```dart
Scaffold(
  appBar: AppBar(title: Text('Home')),
  drawer: AppNavigationMenu(currentRoute: '/home'),
  body: MyContent(),
  bottomNavigationBar: BottomNavigationMenu(
    currentRoute: '/home',
    onDestinationSelected: (route) {
      Navigator.pushReplacementNamed(context, route);
    },
  ),
)
```

#### Tablet/Desktop Layout:
```dart
Row(
  children: [
    NavigationRailMenu(
      currentRoute: '/home',
      extended: MediaQuery.of(context).size.width >= 840, // Extended on desktop
      onDestinationSelected: (route) {
        Navigator.pushReplacementNamed(context, route);
      },
    ),
    VerticalDivider(width: 1),
    Expanded(
      child: Scaffold(
        appBar: AppBar(title: Text('Home')),
        body: MyContent(),
      ),
    ),
  ],
)
```

---

## 📦 Available Widgets

### 1. `AppNavigationMenu` (Drawer)
The traditional navigation drawer with improved MD3 styling.

**Features:**
- Gradient header
- Double-circle avatar with elevation
- Selected state with left border indicator
- Visual hierarchy for menu items

**Usage:**
```dart
Drawer(
  child: AppNavigationMenu(currentRoute: '/home'),
)
```

### 2. `NavigationRailMenu`
Side navigation rail for tablet/desktop.

**Features:**
- Compact mode (icons only) for tablets
- Extended mode (icons + labels) for desktop
- Gradient header in extended mode
- All primary, secondary, and admin navigation items

**Usage:**
```dart
NavigationRailMenu(
  currentRoute: '/home',
  extended: true, // false for compact mode
  onDestinationSelected: (route) {
    Navigator.pushReplacementNamed(context, route);
  },
)
```

### 3. `BottomNavigationMenu`
Bottom navigation bar for mobile devices (shows 5 main items).

**Features:**
- Material 3 NavigationBar component
- Filled icons when selected
- Only shows primary navigation items (Home, My Books, Cart, Wallet, Orders)

**Usage:**
```dart
bottomNavigationBar: BottomNavigationMenu(
  currentRoute: '/home',
  onDestinationSelected: (route) {
    Navigator.pushReplacementNamed(context, route);
  },
)
```

### 4. `ResponsiveNavigationWrapper`
Automatic responsive layout wrapper.

**Features:**
- Automatically switches between layouts based on screen width
- Handles all navigation logic
- Supports AppBar, FloatingActionButton, and all Scaffold properties

**Parameters:**
- `currentRoute` (required): Current page route
- `body` (required): Page content
- `appBar`: Optional AppBar
- `floatingActionButton`: Optional FAB
- `useDrawer`: Show drawer in mobile layout (default: true)
- `useBottomNav`: Show bottom nav in mobile layout (default: true)
- `useRail`: Show navigation rail in tablet/desktop (default: true)

---

## 🎯 Navigation Items

### Primary Items (shown in all layouts)
1. **Home** - `/home`
2. **My Books** - `/my-books`
3. **Cart** - `/cart`
4. **Wallet** - `/wallet`
5. **Orders** - `/orders`

### Secondary Items (Drawer/Rail only)
6. **Settings** - `/settings`
7. **Manage Accounts** - `/accounts`

### Admin Item (if user is admin)
8. **Admin Panel** - `/admin`

---

## 📐 Breakpoints

```dart
// Mobile
width < 600dp  → Drawer + BottomNavigationBar

// Tablet
600dp ≤ width < 840dp  → NavigationRail (compact)

// Desktop
width ≥ 840dp  → NavigationRail (extended)
```

---

## 🎨 Theme Integration

The navigation system automatically uses your app's theme:

```dart
// Uses these color tokens:
- primaryContainer
- primary
- surface
- surfaceContainerHighest
- onSurface
- onSurfaceVariant
- onPrimaryContainer
- outlineVariant
```

Supports both **light** and **dark** themes out of the box.

---

## 🔄 Migration Guide

### From Old Drawer to New System

**Old code:**
```dart
Scaffold(
  appBar: AppBar(title: Text('Home')),
  drawer: AppNavigationMenu(currentRoute: '/home'),
  body: MyContent(),
)
```

**New code (responsive):**
```dart
ResponsiveNavigationWrapper(
  currentRoute: '/home',
  appBar: AppBar(title: Text('Home')),
  body: MyContent(),
)
```

That's it! The wrapper handles everything automatically.

---

## ✅ Checklist for Implementation

When adding navigation to a new page:

- [ ] Import `responsive_navigation_wrapper.dart`
- [ ] Wrap your page with `ResponsiveNavigationWrapper`
- [ ] Pass the current route
- [ ] Move AppBar, body, and FAB to wrapper parameters
- [ ] Test on different screen sizes:
  - [ ] Mobile (< 600dp) - Should show bottom nav + drawer
  - [ ] Tablet (600-840dp) - Should show compact rail
  - [ ] Desktop (≥ 840dp) - Should show extended rail
- [ ] Test theme switching (light/dark)

---

## 📚 Examples

See these files for complete examples:
- Mobile layout: Check any page using `AppNavigationMenu`
- Tablet/Desktop: Use `ResponsiveNavigationWrapper` (automatically adapts)

---

## 🐛 Troubleshooting

**Problem**: Navigation doesn't appear
- ✅ Make sure you're using correct `currentRoute` string
- ✅ Check that route is defined in `main.dart` routes

**Problem**: Selected item not highlighting
- ✅ Verify `currentRoute` matches one of the navigation item routes exactly
- ✅ Routes are case-sensitive

**Problem**: Layout not switching on resize
- ✅ Use `ResponsiveNavigationWrapper` instead of manual layouts
- ✅ Hot reload might not work - try full restart

---

## 📱 Testing

Test the navigation on different screen sizes:

```bash
# Run in Chrome (can resize window)
flutter run -d chrome

# Or use device simulators:
flutter run -d "iPhone 15" # Mobile
flutter run -d "iPad Pro"          # Tablet
flutter run -d "macOS"             # Desktop
```

---

**✨ Built with Material Design 3 principles**
