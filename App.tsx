/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import { useMemo, useState } from 'react';
import {
  Alert,
  ScrollView,
  StatusBar,
  StyleSheet,
  Switch,
  Text,
  TouchableOpacity,
  useColorScheme,
  View,
} from 'react-native';
import {
  SafeAreaProvider,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  return (
    <SafeAreaProvider>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <AppContent />
    </SafeAreaProvider>
  );
}

function AppContent() {
  const safeAreaInsets = useSafeAreaInsets();
  const [quickModeEnabled, setQuickModeEnabled] = useState(true);
  const [selectedCategory, setSelectedCategory] = useState('Safety');

  const featureGroups = useMemo(
    () => [
      {
        title: 'Safety',
        items: [
          {
            title: 'Silent Emergency SOS System',
            description: 'Trigger silent alerts with location sharing.',
          },
          {
            title: 'Safe Route Navigation',
            description: 'Plan safer routes with live check-ins.',
          },
          {
            title: 'Public Transport Safety Companion',
            description: 'Ride monitoring and destination alerts.',
          },
        ],
      },
      {
        title: 'Support',
        items: [
          {
            title: 'Harassment Documentation & Legal Support Platform',
            description: 'Secure incident logs and legal guidance.',
          },
          {
            title: 'Community Safety Network',
            description: 'Connect with nearby verified helpers.',
          },
          {
            title: 'Anonymous Reporting Platform for Workplace Harassment',
            description: 'Confidential reporting with status updates.',
          },
        ],
      },
      {
        title: 'Wellness & Growth',
        items: [
          {
            title: "Women's Health & Hygiene Tracker",
            description: 'Track cycles, symptoms, and reminders.',
          },
          {
            title: 'Self-Defense Training Gamification',
            description: 'Daily drills with progress badges.',
          },
          {
            title: 'Employment & Entrepreneurship Platform for Women',
            description: 'Mentorships, listings, and funding access.',
          },
        ],
      },
    ],
    [],
  );

  return (
    <View style={[styles.container, { paddingTop: safeAreaInsets.top }]}>
      <View style={styles.header}>
        <Text style={styles.title}>SAKHI</Text>
        <Text style={styles.subtitle}>
          A safe, supportive space with tools built for real moments.
        </Text>
      </View>
      <View style={styles.quickActionsCard}>
        <View style={styles.quickActionsHeader}>
          <Text style={styles.cardTitle}>Quick Safety Mode</Text>
          <Switch
            value={quickModeEnabled}
            onValueChange={setQuickModeEnabled}
            trackColor={{ false: '#C2C7CF', true: '#0A7D6A' }}
            thumbColor={quickModeEnabled ? '#FFFFFF' : '#F2F3F5'}
          />
        </View>
        <Text style={styles.cardBody}>
          {quickModeEnabled
            ? 'Enabled. Tap any feature below to auto-share your location with trusted contacts.'
            : 'Disabled. Enable to activate silent SOS shortcuts and rapid check-ins.'}
        </Text>
      </View>
      <View style={styles.categoryRow}>
        {['Safety', 'Support', 'Wellness & Growth'].map(category => {
          const isActive = selectedCategory === category;
          return (
            <TouchableOpacity
              key={category}
              style={[styles.categoryChip, isActive && styles.categoryChipActive]}
              onPress={() => setSelectedCategory(category)}
            >
              <Text
                style={[
                  styles.categoryText,
                  isActive && styles.categoryTextActive,
                ]}
              >
                {category}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}
      >
        {featureGroups
          .filter(group => group.title === selectedCategory)
          .flatMap(group =>
            group.items.map(item => (
              <View style={styles.featureCard} key={item.title}>
                <View style={styles.featureHeader}>
                  <Text style={styles.featureTitle}>{item.title}</Text>
                  <Text style={styles.featureStatus}>
                    {quickModeEnabled ? 'Active' : 'Ready'}
                  </Text>
                </View>
                <Text style={styles.featureDescription}>{item.description}</Text>
                <TouchableOpacity
                  style={styles.featureButton}
                  onPress={() =>
                    Alert.alert(
                      'Feature Preview',
                      `${item.title} is ready to launch.`,
                    )
                  }
                >
                  <Text style={styles.featureButtonText}>Open</Text>
                </TouchableOpacity>
              </View>
            )),
          )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F7FA',
    paddingHorizontal: 20,
  },
  header: {
    paddingVertical: 20,
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
    color: '#0B1B3A',
  },
  subtitle: {
    marginTop: 6,
    fontSize: 15,
    color: '#516079',
    lineHeight: 22,
  },
  quickActionsCard: {
    backgroundColor: '#FFFFFF',
    padding: 16,
    borderRadius: 16,
    shadowColor: '#0B1B3A',
    shadowOpacity: 0.08,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 4,
  },
  quickActionsHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  cardTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: '#0B1B3A',
  },
  cardBody: {
    marginTop: 8,
    fontSize: 14,
    color: '#5A677D',
    lineHeight: 20,
  },
  categoryRow: {
    flexDirection: 'row',
    marginTop: 18,
    marginBottom: 6,
    gap: 8,
    flexWrap: 'wrap',
  },
  categoryChip: {
    paddingVertical: 8,
    paddingHorizontal: 14,
    borderRadius: 16,
    backgroundColor: '#E5EAF2',
  },
  categoryChipActive: {
    backgroundColor: '#0B1B3A',
  },
  categoryText: {
    fontSize: 13,
    color: '#4F5D75',
    fontWeight: '600',
  },
  categoryTextActive: {
    color: '#FFFFFF',
  },
  scrollContent: {
    paddingBottom: 32,
    gap: 12,
  },
  featureCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 18,
    padding: 16,
    shadowColor: '#0B1B3A',
    shadowOpacity: 0.05,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 4 },
    elevation: 2,
  },
  featureHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
  },
  featureTitle: {
    flex: 1,
    fontSize: 16,
    fontWeight: '600',
    color: '#0B1B3A',
  },
  featureStatus: {
    fontSize: 12,
    fontWeight: '600',
    color: '#0A7D6A',
    textTransform: 'uppercase',
  },
  featureDescription: {
    marginTop: 8,
    fontSize: 14,
    color: '#5A677D',
    lineHeight: 20,
  },
  featureButton: {
    marginTop: 12,
    alignSelf: 'flex-start',
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 14,
    backgroundColor: '#0A7D6A',
  },
  featureButtonText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#FFFFFF',
  },
});

export default App;
