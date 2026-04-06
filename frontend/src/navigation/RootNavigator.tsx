// /frontend/src/navigation/RootNavigator.tsx
// FTM — Navigation racine + initialisation + routing selon rôle

import React, { useEffect, useState } from "react";
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

// Admin screens
import AdminDashboardScreen from "../screens/admin/AdminDashboardScreen";

import type { AppRoute } from "../types/database";

// ─────────────────────────────────────────────
// Types de navigation
// ─────────────────────────────────────────────

export type AuthStackParamList = {
  PhoneInput: undefined;
  OTPVerification: { formattedPhone: string };
  ProfileSetup: { authUserId: string; formattedPhone: string };
};

export type ClientStackParamList = {
  ClientHome: undefined;
};

export type DriverStackParamList = {
  DriverHome: undefined;
};

export type AdminStackParamList = {
  AdminHome: undefined;
};

const AuthStack = createNativeStackNavigator<AuthStackParamList>();
const ClientStack = createNativeStackNavigator<ClientStackParamList>();
const DriverStack = createNativeStackNavigator<DriverStackParamList>();
const AdminStack = createNativeStackNavigator<AdminStackParamList>();

// ─────────────────────────────────────────────
// Stacks par rôle
// ─────────────────────────────────────────────

function ClientNavigator() {
  return (
    <ClientStack.Navigator screenOptions={{ headerShown: false }}>
      <ClientStack.Screen
        name="ClientHome"
        component={CreateMissionScreen as any}
      />
    </ClientStack.Navigator>
  );
}

function DriverNavigator() {
  return (
    <DriverStack.Navigator screenOptions={{ headerShown: false }}>
      <DriverStack.Screen
        name="DriverHome"
        component={DriverHomeScreen as any}
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

// ─────────────────────────────────────────────
// Initialisation de l'app
// ─────────────────────────────────────────────

async function initializeApp(): Promise<{ route: AppRoute }> {
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
    case "driver":
      return { route: "DriverHomeStack" };
    case "admin":
      return { route: "AdminStack" };
    default:
      return { route: "AuthStack" };
  }
}

// ─────────────────────────────────────────────
// Composant principal
// ─────────────────────────────────────────────

export default function RootNavigator() {
  const [isLoading, setIsLoading] = useState(true);
  const [initialRoute, setInitialRoute] = useState<AppRoute>("AuthStack");

  useEffect(() => {
    initializeApp().then(({ route }) => {
      setInitialRoute(route);
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
          <AuthStack.Screen
            name="ProfileSetup"
            component={ProfileSetupScreen}
          />
        </AuthStack.Navigator>
      )}
      {showClient && <ClientNavigator />}
      {showDriver && <DriverNavigator />}
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
