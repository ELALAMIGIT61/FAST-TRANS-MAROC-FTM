// /components/DateOnlyField.tsx
// Fast Trans Maroc — Volet 4b-5 — Saisie d'une date seule (sans heure)
// Valeur au format 'YYYY-MM-DD' (format des colonnes date de Supabase),
// sans conversion de fuseau horaire.

import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Platform } from 'react-native';
import DateTimePicker from '@react-native-community/datetimepicker';

interface DateOnlyFieldProps {
  label:    string;
  value:    string | null;          // 'YYYY-MM-DD'
  onChange: (value: string) => void;
  minDate?: string;                 // 'YYYY-MM-DD' inclus
  maxDate?: string;                 // 'YYYY-MM-DD' inclus
  hint?:    string | null;
  error?:   string | null;
}

export function toIsoDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function todayIsoDate(): string {
  return toIsoDate(new Date());
}

export function formatIsoDateFr(value: string | null | undefined): string {
  if (!value) return '';
  const [y, m, d] = value.slice(0, 10).split('-');
  return `${d}/${m}/${y}`;
}

function isoToLocalDate(value: string): Date {
  const [y, m, d] = value.slice(0, 10).split('-').map(Number);
  return new Date(y, m - 1, d);
}

function DateOnlyField({ label, value, onChange, minDate, maxDate, hint, error }: DateOnlyFieldProps) {
  const [showPicker, setShowPicker] = useState(false);

  if (Platform.OS === 'web') {
    return (
      <View style={styles.wrapper}>
        <Text style={styles.label}>{label}</Text>
        <input
          type="date"
          value={value ?? ''}
          min={minDate}
          max={maxDate}
          onChange={e => {
            const v = (e.target as any).value as string;
            if (v) onChange(v);
          }}
          style={{
            border: error ? '1px solid #DC3545' : '1px solid #DDD',
            borderRadius: 10,
            padding: 12,
            fontSize: 15,
            backgroundColor: '#FFFFFF',
            width: '100%',
            boxSizing: 'border-box',
          } as any}
        />
        {hint ? <Text style={styles.hint}>{hint}</Text> : null}
        {error ? <Text style={styles.errorText}>{error}</Text> : null}
      </View>
    );
  }

  return (
    <View style={styles.wrapper}>
      <Text style={styles.label}>{label}</Text>
      <TouchableOpacity
        style={[styles.picker, error ? styles.pickerError : null]}
        onPress={() => setShowPicker(true)}
      >
        <Text style={{ color: value ? '#1A1A2E' : '#999', fontSize: 15 }}>
          {value ? formatIsoDateFr(value) : 'Sélectionner une date'}
        </Text>
      </TouchableOpacity>

      {showPicker && (
        <DateTimePicker
          value={value ? isoToLocalDate(value) : new Date()}
          mode="date"
          display={Platform.OS === 'ios' ? 'spinner' : 'default'}
          minimumDate={minDate ? isoToLocalDate(minDate) : undefined}
          maximumDate={maxDate ? isoToLocalDate(maxDate) : undefined}
          onChange={(_event: unknown, selected?: Date) => {
            setShowPicker(false);
            if (selected) onChange(toIsoDate(selected));
          }}
        />
      )}

      {hint ? <Text style={styles.hint}>{hint}</Text> : null}
      {error ? <Text style={styles.errorText}>{error}</Text> : null}
    </View>
  );
}

export default React.memo(DateOnlyField);

const styles = StyleSheet.create({
  wrapper:     { marginBottom: 12 },
  label:       { fontSize: 13, color: '#666', marginBottom: 4 },
  picker:      {
    borderWidth: 1, borderColor: '#DDD', borderRadius: 10,
    padding: 12, backgroundColor: '#FFFFFF',
  },
  pickerError: { borderColor: '#DC3545' },
  hint:        { fontSize: 12, color: '#555', marginTop: 6, fontStyle: 'italic' },
  errorText:   { color: '#DC3545', fontSize: 12, marginTop: 4 },
});
