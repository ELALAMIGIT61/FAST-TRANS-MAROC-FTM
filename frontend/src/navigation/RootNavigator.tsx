// /frontend/src/navigation/RootNavigator.tsx
// FTM — Navigation racine + initialisation + routing selon rôle

import React, { useEffect, useRef, useState } from "react";
import { View, ActivityIndicator, StyleSheet } from "react-native";
import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";

import { supabase } from "../lib/supabaseClient";
import { loadSavedLanguage } from "../services/i18nService";
import { COLORS } from "../constants/theme";

// Auth screens
import PhoneInputScreen from "../screens/auth/PhoneInputScreen";
import OTPVerificationScreen from "../screens/auth/OTPVerificationScreen";
import ProfileSetupScreen from "../screens/auth/ProfileSetupScreen";

// Client screens
import CreateMissionScreen from "../screens/client/CreateMissionScreen";

// Driver screens
import DriverHomeScreen from "../screens/driver/DriverHomeScreen";
import WalletDashboardScreen from "../screens/driver/WalletDashboardScreen";
import WalletTopupScreen from "../screens/driver/WalletTopupScreen";
import TransactionHistoryScreen from "../screens/driver/TransactionHistoryScreen";
import VehicleInfoScreen from "../screens/driver/onboarding/VehicleInfoScreen";
import LegalDocumentsScreen from "../screens/driver/onboarding/LegalDocumentsScreen";
import DocumentUploadScreen from "../screens/driver/onboarding/DocumentUploadScreen";
import PendingVerificationScreen from "../screens/driver/onboarding/PendingVerificationScreen";

// Admin screens
import AdminDashboardScreen from "../screens/admin/AdminDashboardScreen";

import type { AppRoute } from "../types/database";

export type AuthStackParamList = {
  PhoneInput: undefined;
  OTPVerification: { formattedPhone: string };
  ProfileSetup: { authUserId: string; formattedPhone: string };
};

export type ClientStackParamList = {
  ClientHome: undefined;
};

export type DriverStackParamList = {
  DriverHome: { driverId: string; vehicleCategory: string };
  WalletDashboard: { driverId: string };
  WalletTopup: { walletId: string; currentBalance: number; minimumBalance: number };
  TransactionHistory: { walletId: string };
};

export type DriverOnboardingStackParamList = {
  VehicleInfo: undefined;
  LegalDocuments: { driverId: string };
  DocumentUpload: { driverId: string };
  PendingVerification: { driverId: string };
};

export type DriverPendingStackParamList = {
  PendingVerification: { driverId: string };
};

export type AdminStackParamList = {
  AdminHome: undefined;
};

const AuthStack = createNativeStackNavigator<AuthStackParamList>();
const ClientStack = createNativeStackNavigator<ClientStackParamList>();
const DriverStack = createNativeStackNavigator<DriverStackParamList>();
const DriverOnboardingStack = createNativeStackNavigator<DriverOnboardingStackParamList>();
const DriverPendingStack = createNativeStackNavigator<DriverPendingStackParamList>();
const AdminStack = createNativeStackNavigator<AdminStackParamList>();

function ClientNavigator({ clientProfileId }: { clientProfileId: string }) {
  return (
    <ClientStack.Navigator screenOptions={{ headerShown: false }}>
      <ClientStack.Screen
        name="ClientHome"
        component={CreateMissionScreen as any}
        initialParams={{ clientProfileId }}
      />
    </ClientStack.Navigator>
  );
}

function DriverOnboardingNavigator() {
  return (
    <DriverOnboardingStack.Navigator screenOptions={{ headerShown: false }}>
      <DriverOnboardingStack.Screen name="VehicleInfo" component={VehicleInfoScreen as any} />
      <DriverOnboardingStack.Screen name="LegalDocuments" component={LegalDocumentsScreen as any} />
      <DriverOnboardingStack.Screen name="DocumentUpload" component={DocumentUploadScreen as any} />
      <DriverOnboardingStack.Screen name="PendingVerification" component={PendingVerificationScreen as any} />
    </DriverOnboardingStack.Navigator>
  );
}

function DriverPendingNavigator({ driverId }: { driverId: string }) {
  return (
    <DriverPendingStack.Navigator screenOptions={{ headerShown: false }}>
      <DriverPendingStack.Screen
        name="PendingVerification"
        component={PendingVerificationScreen as any}
        initialParams={{ driverId }}
      />
    </DriverPendingStack.Navigator>
  );
}

function DriverNavigator({ driverId, vehicleCategory }: { driverId: string; vehicleCategory: string }) {
  return (
    <DriverStack.Navigator screenOptions={{ headerShown: false }}>
      <DriverStack.Screen
        name="DriverHome"
        component={DriverHomeScreen as any}
        initialParams={{ driverId, vehicleCategory }}
      />
      <DriverStack.Screen
        name="WalletDashboard"
        component={WalletDashboardScreen as any}
      />
      <DriverStack.Screen
        name="WalletTopup"
        component={WalletTopupScreen as any}
      />
      <DriverStack.Screen
        name="TransactionHistory"
        component={TransactionHistoryScreen as any}
      />
    </DriverStack.Navigator>
  );
}

function AdminNavigator() {
  return (
    <AdminStack.Navigator screenOptions={{ headerShown: false }}>
      <AdminStack.Screen
        name="AdminHome"
        component={AdminDashboardScreen as any}
      />
    </AdminStack.Navigator>
  );
}

async function initializeApp(): Promise<{ route: AppRoute; driverId?: string; vehicleCategory?: string }> {
  console.log("[FTM-DEBUG] App - Initializing", {
    timestamp: new Date().toISOString(),
  });

  await loadSavedLanguage();

  const {
    data: { session },
    error,
  } = await supabase.auth.getSession();

  console.log("[FTM-DEBUG] App - Session check", {
    hasSession: !!session,
    userId: session?.user?.id,
    error: error?.message,
  });

  if (!session) {
    return { route: "AuthStack" };
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, role, full_name, is_active, language_preference")
    .eq("user_id", session.user.id)
    .single();

  console.log("[FTM-DEBUG] App - Profile loaded", {
    profileId: profile?.id,
    role: profile?.role,
    isActive: profile?.is_active,
  });

  if (!profile) return { route: "ProfileSetupScreen" };
  if (!profile.is_active) return { route: "AccountSuspendedScreen" };

  switch (profile.role) {
    case "client":
      return { route: "ClientHomeStack" };
    case "driver": {
        const { data: driver } = await supabase
          .from("drivers")
          .select("id, vehicle_category, is_verified, driver_license_number, driver_license_url, vehicle_registration_url, insurance_url, technical_inspection_url")
          .eq("profile_id", profile.id)
          .single();
        if (!driver) return { route: "DriverOnboardingStack" };
        if (!driver.driver_license_number) return { route: "DriverOnboardingStack" };
        if (!driver.driver_license_url &&
            !driver.vehicle_registration_url &&
            !driver.insurance_url &&
            !driver.technical_inspection_url) return { route: "DriverOnboardingStack" };
        if (!driver.is_verified) return { route: "DriverPendingStack", driverId: driver.id };
        return { route: "DriverHomeStack", driverId: driver.id, vehicleCategory: driver.vehicle_category };
      }
    case "admin":
      return { route: "AdminStack" };
    default:
      return { route: "AuthStack" };
  }
}

export default function RootNavigator() {
  const [isLoading, setIsLoading] = useState(true);
  const [initialRoute, setInitialRoute] = useState<AppRoute>("AuthStack");
  const [clientProfileId, setClientProfileId] = useState<string>("");
  const [driverProfileId, setDriverProfileId] = useState<string>("");
  const [driverVehicleCategory, setDriverVehicleCategory] = useState<string>("");
  const initialRouteRef = useRef<AppRoute>("AuthStack");

  useEffect(() => {
    initializeApp().then(({ route, driverId, vehicleCategory }) => {
      setInitialRoute(route);
      initialRouteRef.current = route;
      if (driverId) setDriverProfileId(driverId);
      if (vehicleCategory) setDriverVehicleCategory(vehicleCategory);
      setIsLoading(false);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, session) => {
      console.log("[FTM-DEBUG] Auth - State change", {
        event,
        userId: session?.user?.id,
        timestamp: new Date().toISOString(),
      });

      if (event === "SIGNED_OUT") {
        setInitialRoute("AuthStack");
        initialRouteRef.current = "AuthStack";
      }
      if (event === "SIGNED_IN" && session?.user) {
        if (initialRouteRef.current !== "DriverOnboardingStack") {
          initializeApp().then(({ route, driverId, vehicleCategory }) => {
            setInitialRoute(route);
            initialRouteRef.current = route;
            if (driverId) setDriverProfileId(driverId);
            if (vehicleCategory) setDriverVehicleCategory(vehicleCategory);
          });
        }
      }

      if (event === "TOKEN_REFRESHED") {
        console.log("[FTM-DEBUG] Auth - Token refreshed successfully");
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  if (isLoading) {
    return (
      <View style={styles.splash}>
        <ActivityIndicator size="large" color={COLORS.primary} />
      </View>
    );
  }

  const showAuth =
    initialRoute === "AuthStack" || initialRoute === "ProfileSetupScreen";
  const showClient = initialRoute === "ClientHomeStack";
  const showDriver = initialRoute === "DriverHomeStack";
  const showDriverOnboarding = initialRoute === "DriverOnboardingStack";
  const showDriverPending = initialRoute === "DriverPendingStack";
  const showAdmin = initialRoute === "AdminStack";

  return (
    <NavigationContainer>
      {showAuth && (
        <AuthStack.Navigator screenOptions={{ headerShown: false }}>
          <AuthStack.Screen name="PhoneInput" component={PhoneInputScreen} />
          <AuthStack.Screen
            name="OTPVerification"
            component={OTPVerificationScreen}
          />
          <AuthStack.Screen name="ProfileSetup">
            {(props) => (
              <ProfileSetupScreen
                {...props}
                onProfileCreated={(role: string, profileId: string) => {
                  setClientProfileId(profileId);
                  const newRoute = role === "client" ? "ClientHomeStack" :
                    role === "driver" ? "DriverOnboardingStack" : "AdminStack";
                  setInitialRoute(newRoute);
                  initialRouteRef.current = newRoute;
                }}
              />
            )}
          </AuthStack.Screen>
        </AuthStack.Navigator>
      )}
      {showClient && <ClientNavigator clientProfileId={clientProfileId} />}
      {showDriver && <DriverNavigator driverId={driverProfileId} vehicleCategory={driverVehicleCategory} />}
      {showDriverOnboarding && <DriverOnboardingNavigator />}
      {showDriverPending && <DriverPendingNavigator driverId={driverProfileId} />}
      {showAdmin && <AdminNavigator />}
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  splash: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: COLORS.background,
  },
});
