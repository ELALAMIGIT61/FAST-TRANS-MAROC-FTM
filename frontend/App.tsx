import { StatusBar } from "expo-status-bar";
import { SafeAreaProvider, SafeAreaView } from "react-native-safe-area-context";
import RootNavigator from "./src/navigation/RootNavigator";

// Session 3.4 : sur telephone, le contenu commence sous la barre d'etat
// (heure, batterie) et s'arrete au-dessus des boutons Android. Sur le web,
// ces marges valent zero : aucun changement.
export default function App() {
  return (
    <SafeAreaProvider>
      <SafeAreaView style={{ flex: 1, backgroundColor: "#F8F9FA" }}>
        <RootNavigator />
      </SafeAreaView>
      <StatusBar style="dark" />
    </SafeAreaProvider>
  );
}
