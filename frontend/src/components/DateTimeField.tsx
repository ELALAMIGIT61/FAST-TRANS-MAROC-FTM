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

function DateTimeField({ label, value, onChange, error }: DateTimeFieldProps) {
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [showTimePicker, setShowTimePicker] = useState(false);
  const [pendingDate, setPendingDate] = useState<Date | null>(null);
  const [internalError, setInternalError] = useState<string | null>(null);
  const [localDateStr, setLocalDateStr] = useState<string | null>(null);
  const [localTimeStr, setLocalTimeStr] = useState<string | null>(null);

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

  if (Platform.OS === 'web') {
    const dateStr = localDateStr ?? (value ? value.toISOString().split('T')[0] : '');
    const timeStr = localTimeStr ?? (value
      ? `${String(value.getHours()).padStart(2, '0')}:${String(value.getMinutes()).padStart(2, '0')}`
      : '');

    const applyCombined = (combined: Date) => {
      if (combined < new Date()) {
        setInternalError('La date et l\'heure sélectionnées sont déjà passées. Merci de recommencer.');
        return;
      }
      setInternalError(null);
      onChange(combined);
    };

    const onDateInputChange = (newDateStr: string) => {
      setLocalDateStr(newDateStr);
    };

    const onTimeInputChange = (newTimeStr: string) => {
      setLocalTimeStr(newTimeStr);
    };

    const handleWebDateChange = (newDateStr: string) => {
      if (!newDateStr) return;
      const [y, m, d] = newDateStr.split('-').map(Number);
      const base = value ?? new Date();
      applyCombined(new Date(y, m - 1, d, base.getHours(), base.getMinutes(), 0, 0));
      setLocalDateStr(null);
    };

    const handleWebTimeChange = (newTimeStr: string) => {
      if (!newTimeStr) return;
      const [h, min] = newTimeStr.split(':').map(Number);
      const base = value ?? new Date();
      applyCombined(new Date(base.getFullYear(), base.getMonth(), base.getDate(), h, min, 0, 0));
      setLocalTimeStr(null);
    };

    return (
      <View style={styles.wrapper}>
        <Text style={styles.label}>{label}</Text>
        <input
          type="date"
          min={new Date().toISOString().split('T')[0]}
          value={dateStr}
          onChange={e => onDateInputChange((e.target as any).value)}
          onBlur={e => handleWebDateChange((e.target as any).value)}
          style={{
            border: displayError ? '1px solid #DC3545' : '1px solid #DDD',
            borderRadius: 10,
            padding: 14,
            fontSize: 15,
            backgroundColor: '#FAFAFA',
            width: '100%',
            boxSizing: 'border-box',
            marginBottom: 8,
          } as any}
        />
        <input
          type="time"
          value={timeStr}
          onChange={e => onTimeInputChange((e.target as any).value)}
          onBlur={e => handleWebTimeChange((e.target as any).value)}
          style={{
            border: displayError ? '1px solid #DC3545' : '1px solid #DDD',
            borderRadius: 10,
            padding: 14,
            fontSize: 15,
            backgroundColor: '#FAFAFA',
            width: '100%',
            boxSizing: 'border-box',
          } as any}
        />
        {displayError ? <Text style={styles.errorText}>{displayError}</Text> : null}
      </View>
    );
  }

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

export default React.memo(DateTimeField);

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
