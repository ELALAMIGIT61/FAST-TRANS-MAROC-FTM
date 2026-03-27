#!/bin/bash
cat > frontend/App.tsx << 'ENDOFFILE'
import React from 'react';
import { StatusBar } from 'expo-status-bar';
import RootNavigator from './src/navigation/RootNavigator';

export default function App() {
  return (
    <>
      <StatusBar style="auto" />
      <RootNavigator />
    </>
  );
}
ENDOFFILE
echo "✅ App.tsx créé"