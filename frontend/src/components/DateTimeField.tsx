import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Platform } from 'react-native';
import DateTimePicker from '@react-native-community/datetimepicker';
import { COLORS } from '../constants/theme';

interface DateTimeFieldProps {
  label: string;
  value: Date | null;
  onChange: (d: Date) => void;
  error?: string | null;
}

export default function DateTimeField({ label, value, onChange, error }: DateTimeFieldProps) {
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [showTimePicker, setShowTimePicker] = useState(false);
  const [pendingDate, setPendingDate] = useState<Date | null>(null);
  const [internalError, setInternalError] = useState<string | null>(null);

  function openPicker() {
    setInternalError(null);
    setShowDatePicker(true);
  }

  function onDateSelected(_event: unknown, selectedDate?: Date) {
    setShowDatePicker(false);
    if (!selectedDate) return;
    setPendingDate(selectedDate);
    setShowTimePicker(true);
  }

  function onTimeSelected(_event: unknown, selectedTime?: Date) {
    setShowTimePicker(false);
    if (!selectedTime || !pendingDate) {
      setPendingDate(null);
      return;
    }

    const combined = new Date(
      pendingDate.getFullYear(),
      pendingDate.getMonth(),
      pendingDate.getDate(),
      selectedTime.getHours(),
      selectedTime.getMinutes(),
      0,
      0
    );

    setPendingDate(null);

    if (combined < new Date()) {
      setInternalError('La date et l\'heure sélectionnées sont déjà passées. Merci de recommencer.');
      return;
    }

    setInternalError(null);
    onChange(combined);
  }

  const displayError = error ?? internalError;

  return (
    <View style={styles.wrapper}>
      <Text style={styles.label}>{label}</Text>
      <TouchableOpacity
        style={[styles.picker, displayError ? styles.pickerError : null]}
        onPress={openPicker}
      >
        <Text style={{ color: value ? COLORS.text : '#999', fontSize: 15 }}>
          {value ? value.toLocaleString('fr-FR') : 'Sélectionner une date et une heure'}
        </Text>
      </TouchableOpacity>

      {showDatePicker && (
        <DateTimePicker
          value={pendingDate ?? value ?? new Date()}
          mode="date"
          display={Platform.OS === 'ios' ? 'spinner' : 'default'}
          minimumDate={new Date()}
          onChange={onDateSelected}
        />
      )}

      {showTimePicker && (
        <DateTimePicker
          value={pendingDate ?? new Date()}
          mode="time"
          display={Platform.OS === 'ios' ? 'spinner' : 'default'}
          onChange={onTimeSelected}
        />
      )}

      {displayError ? <Text style={styles.errorText}>{displayError}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: { marginBottom: 14 },
  label: { fontSize: 13, color: '#666', marginBottom: 4 },
  picker: {
    borderWidth: 1,
    borderColor: '#DDD',
    borderRadius: 10,
    padding: 14,
    backgroundColor: '#FAFAFA',
  },
  pickerError: { borderColor: '#DC3545' },
  errorText: { color: '#DC3545', fontSize: 12, marginTop: 4 },
});
