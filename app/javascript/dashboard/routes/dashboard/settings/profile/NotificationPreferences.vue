<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useUISettings } from 'dashboard/composables/useUISettings';
import TableHeaderCell from 'dashboard/components/widgets/TableHeaderCell.vue';
import CheckBox from 'v3/components/Form/CheckBox.vue';
import {
  hasPushPermissions,
  requestPushPermissions,
  verifyServiceWorkerExistence,
} from 'dashboard/helper/pushHelper.js';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { NOTIFICATION_TYPES } from './constants';

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();
const { accountId } = useAccount();
const { uiSettings, updateUISettings } = useUISettings();
const selectedEmailFlags = ref([]);
const selectedPushFlags = ref([]);
const hasEnabledPushPermissions = ref(false);
const hasPushAPISupport = computed(() => 'Notification' in window);
const browserPushEnabled = computed(
  () => uiSettings.value.browser_push_enabled ?? hasEnabledPushPermissions.value
);
const filteredNotificationTypes = computed(() => {
  const isSLAEnabled = getters['accounts/isFeatureEnabledonAccount'].value(
    accountId.value,
    FEATURE_FLAGS.SLA
  );
  return NOTIFICATION_TYPES.filter(
    notification => isSLAEnabled || !notification.value.startsWith('sla_')
  );
});

watch(
  () => getters['userNotificationSettings/getSelectedEmailFlags'].value,
  value => {
    selectedEmailFlags.value = value || [];
  },
  { immediate: true }
);
watch(
  () => getters['userNotificationSettings/getSelectedPushFlags'].value,
  value => {
    selectedPushFlags.value = value || [];
  },
  { immediate: true }
);

const onRegistrationSuccess = () => {
  hasEnabledPushPermissions.value = true;
};
const authorizeBrowserPush = () => {
  requestPushPermissions({ onSuccess: onRegistrationSuccess });
};
const onRequestPermissions = value => {
  updateUISettings({ browser_push_enabled: value });
  if (value) {
    authorizeBrowserPush();
  } else {
    verifyServiceWorkerExistence(registration =>
      registration.pushManager
        .getSubscription()
        .then(subscription => {
          if (subscription) return subscription.unsubscribe();
          return null;
        })
        .finally(() => {
          hasEnabledPushPermissions.value = false;
        })
    );
  }
};

onMounted(() => {
  if (hasPushPermissions()) {
    verifyServiceWorkerExistence(registration =>
      registration.pushManager.getSubscription().then(subscription => {
        hasEnabledPushPermissions.value = !!subscription;
        if (browserPushEnabled.value && !subscription) authorizeBrowserPush();
      })
    );
  }
  store.dispatch('userNotificationSettings/get');
});

const checkFlagStatus = (type, flagType) => {
  const selected =
    type === 'email' ? selectedEmailFlags.value : selectedPushFlags.value;
  return selected.includes(`${type}_${flagType}`);
};
const updateNotificationSettings = async () => {
  try {
    await store.dispatch('userNotificationSettings/update', {
      selectedEmailFlags: selectedEmailFlags.value,
      selectedPushFlags: selectedPushFlags.value,
    });
    useAlert(t('PROFILE_SETTINGS.FORM.API.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(t('PROFILE_SETTINGS.FORM.API.UPDATE_ERROR'));
  }
};
const handleInput = (type, id) => {
  const selected = type === 'email' ? selectedEmailFlags : selectedPushFlags;
  selected.value = selected.value.includes(id)
    ? selected.value.filter(flag => flag !== id)
    : [...selected.value, id];
  updateNotificationSettings();
};
const handleEmailInput = id => handleInput('email', id);
const handlePushInput = id => handleInput('push', id);
</script>

<template>
  <div id="profile-settings-notifications" class="flex flex-col gap-6">
    <!-- Layout for desktop devices -->
    <div class="hidden sm:block">
      <div
        class="grid content-center h-12 grid-cols-12 gap-4 py-0 rounded-t-xl"
      >
        <TableHeaderCell
          :span="7"
          label="`${$t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.TYPE_TITLE')}`"
        >
          <span class="text-heading-3 normal-case text-n-slate-12">
            {{ $t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.TYPE_TITLE') }}
          </span>
        </TableHeaderCell>
        <TableHeaderCell
          :span="2"
          label="`${$t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.EMAIL')}`"
        >
          <span class="text-heading-3 normal-case text-n-slate-12">
            {{ $t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.EMAIL') }}
          </span>
        </TableHeaderCell>
        <TableHeaderCell
          :span="3"
          label="`${$t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.PUSH')}`"
        >
          <div class="flex items-center justify-between gap-1">
            <span
              class="text-heading-3 normal-case text-n-slate-12 whitespace-nowrap"
            >
              {{ $t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.PUSH') }}
            </span>
          </div>
        </TableHeaderCell>
      </div>
      <div
        v-for="(notification, index) in filteredNotificationTypes"
        :key="index"
      >
        <div
          class="grid items-center content-center h-12 grid-cols-12 gap-4 py-0 rounded-t-xl"
        >
          <div
            class="flex flex-row items-start gap-2 col-span-7 px-0 py-2 text-sm tracking-[0.5] rtl:text-right"
          >
            <span class="text-body-main text-n-slate-12">
              {{ $t(notification.label) }}
            </span>
          </div>
          <div
            v-for="(type, typeIndex) in ['email', 'push']"
            :key="typeIndex"
            class="flex items-start gap-2 px-0 text-sm tracking-[0.5] text-left rtl:text-right"
            :class="`col-span-${type === 'push' ? 3 : 2}`"
          >
            <CheckBox
              :value="`${type}_${notification.value}`"
              :is-checked="checkFlagStatus(type, notification.value)"
              @update="id => handleInput(type, id)"
            />
          </div>
        </div>
      </div>
    </div>
    <!--  Layout for mobile devices -->
    <div class="flex flex-col gap-6 sm:hidden">
      <span class="text-heading-3 text-n-slate-12">
        {{ $t('PROFILE_SETTINGS.FORM.EMAIL_NOTIFICATIONS_SECTION.TITLE') }}
      </span>
      <div class="flex flex-col gap-4">
        <div
          v-for="(notification, index) in filteredNotificationTypes"
          :key="index"
          class="flex flex-row items-start gap-2"
        >
          <CheckBox
            :id="`email_${notification.value}`"
            :value="`email_${notification.value}`"
            :is-checked="checkFlagStatus('email', notification.value)"
            @update="handleEmailInput"
          />
          <span class="text-body-main text-n-slate-12">{{
            $t(notification.label)
          }}</span>
        </div>
      </div>

      <div class="flex items-center justify-start gap-2">
        <span class="text-heading-3 text-n-slate-12">
          {{ $t('PROFILE_SETTINGS.FORM.PUSH_NOTIFICATIONS_SECTION.TITLE') }}
        </span>
      </div>

      <div class="flex flex-col gap-4">
        <div
          v-for="(notification, index) in filteredNotificationTypes"
          :key="index"
          class="flex flex-row items-start gap-2"
        >
          <CheckBox
            :id="`push_${notification.value}`"
            :value="`push_${notification.value}`"
            :is-checked="checkFlagStatus('push', notification.value)"
            @update="handlePushInput"
          />
          <span class="text-body-main text-n-slate-12">{{
            $t(notification.label)
          }}</span>
        </div>
      </div>
    </div>

    <div
      class="flex items-center justify-between w-full gap-2 p-4 border border-solid border-n-weak rounded-xl"
    >
      <div class="flex flex-row items-center gap-2">
        <fluent-icon
          icon="alert"
          class="flex-shrink-0 text-n-slate-12"
          size="18"
        />
        <span class="text-body-main text-n-slate-12">
          {{ $t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.BROWSER_PERMISSION') }}
        </span>
      </div>
      <ToggleSwitch
        :model-value="browserPushEnabled"
        @update:model-value="onRequestPermissions"
      />
    </div>
    <div
      v-if="
        hasPushAPISupport && browserPushEnabled && !hasEnabledPushPermissions
      "
      class="flex items-center justify-between gap-4 text-sm text-n-slate-11"
    >
      <span>{{
        $t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.BROWSER_PERMISSION_PENDING')
      }}</span>
      <Button
        :label="$t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.BROWSER_AUTHORIZE')"
        @click="authorizeBrowserPush"
      />
    </div>
  </div>
</template>
