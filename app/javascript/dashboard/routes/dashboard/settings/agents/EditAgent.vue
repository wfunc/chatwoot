<script setup>
import { ref, computed } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, requiredIf } from '@vuelidate/validators';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Auth from '../../../../api/auth';
import wootConstants from 'dashboard/constants/globals';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    default: '',
  },
  type: {
    type: String,
    default: '',
  },
  availability: {
    type: String,
    default: '',
  },
  provider: {
    type: String,
    default: '',
  },
  customRoleId: {
    type: Number,
    default: null,
  },
  merchantStatus: {
    type: String,
    default: 'active',
  },
  merchantExpiresAt: {
    type: String,
    default: '',
  },
  agentLimit: {
    type: Number,
    default: null,
  },
});

const emit = defineEmits(['close']);

const { AVAILABILITY_STATUS_KEYS } = wootConstants;

const store = useStore();
const { t } = useI18n();
const { isAdmin, isMerchant } = useAdmin();

const formatDateTimeLocal = value => {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';

  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');

  return `${year}-${month}-${day}T${hours}:${minutes}`;
};

const agentName = ref(props.name);
const agentAvailability = ref(props.availability);
const selectedRoleId = ref(props.customRoleId || props.type);
const agentCredentials = ref({ email: props.email });
const merchantStatus = ref(props.merchantStatus || 'active');
const merchantExpiresAt = ref(formatDateTimeLocal(props.merchantExpiresAt));
const agentLimit = ref(props.agentLimit);
const agentPassword = ref('');
const agentPasswordConfirmation = ref('');

const rules = {
  agentName: { required, minLength: minLength(1) },
  selectedRoleId: { required },
  agentAvailability: { required },
  agentPassword: {
    required: requiredIf(() => !!agentPasswordConfirmation.value),
    minLength: minLength(6),
  },
  agentPasswordConfirmation: {
    required: requiredIf(() => !!agentPassword.value),
    minLength: minLength(6),
    isEqPassword: value => !value || value === agentPassword.value,
  },
  agentLimit: {
    required: requiredIf(
      () => isAdmin.value && selectedRoleId.value === 'merchant'
    ),
    isValid: value =>
      !isAdmin.value ||
      selectedRoleId.value !== 'merchant' ||
      Number(value) >= 0,
  },
};

const v$ = useVuelidate(rules, {
  agentName,
  selectedRoleId,
  agentAvailability,
  agentPassword,
  agentPasswordConfirmation,
  agentLimit,
});

const pageTitle = computed(
  () => `${t('AGENT_MGMT.EDIT.TITLE')} - ${props.name}`
);

const uiFlags = useMapGetter('agents/getUIFlags');
const getCustomRoles = useMapGetter('customRole/getCustomRoles');

const roles = computed(() => {
  if (isMerchant.value) {
    return [
      {
        id: 'agent',
        name: 'agent',
        label: t('AGENT_MGMT.AGENT_TYPES.AGENT'),
      },
    ];
  }

  const defaultRoles = [
    {
      id: 'administrator',
      name: 'administrator',
      label: t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR'),
    },
    {
      id: 'agent',
      name: 'agent',
      label: t('AGENT_MGMT.AGENT_TYPES.AGENT'),
    },
    {
      id: 'merchant',
      name: 'merchant',
      label: t('AGENT_MGMT.AGENT_TYPES.MERCHANT'),
    },
  ];

  const customRoles = getCustomRoles.value.map(role => ({
    id: role.id,
    name: `custom_${role.id}`,
    label: role.name,
  }));

  return [...defaultRoles, ...customRoles];
});

const selectedRole = computed(() =>
  roles.value.find(
    role =>
      role.id === selectedRoleId.value || role.name === selectedRoleId.value
  )
);

const statusList = computed(() => {
  return [
    t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.ONLINE'),
    t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.BUSY'),
    t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.OFFLINE'),
  ];
});

const availabilityStatuses = computed(() =>
  statusList.value.map((statusLabel, index) => ({
    label: statusLabel,
    value: AVAILABILITY_STATUS_KEYS[index],
    disabled: props.availability === AVAILABILITY_STATUS_KEYS[index],
  }))
);

const merchantStatuses = computed(() => {
  return [
    {
      label: t('AGENT_MGMT.MERCHANT_STATUS.ACTIVE'),
      value: 'active',
    },
    {
      label: t('AGENT_MGMT.MERCHANT_STATUS.SUSPENDED'),
      value: 'suspended',
    },
    {
      label: t('AGENT_MGMT.MERCHANT_STATUS.EXPIRED'),
      value: 'expired',
    },
  ];
});

const editAgent = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const payload = {
      id: props.id,
      name: agentName.value,
      availability: agentAvailability.value,
    };

    if (agentPassword.value) {
      payload.password = agentPassword.value;
      payload.password_confirmation = agentPasswordConfirmation.value;
    }

    if (selectedRole.value.name === 'merchant') {
      payload.role = 'merchant';
      payload.custom_role_id = null;
      payload.agent_limit = Number(agentLimit.value);
      payload.merchant_status = merchantStatus.value;
      payload.merchant_expires_at = merchantExpiresAt.value || null;
    } else if (selectedRole.value.name.startsWith('custom_')) {
      payload.custom_role_id = selectedRole.value.id;
    } else {
      payload.role = selectedRole.value.name;
      payload.custom_role_id = null;
    }

    await store.dispatch('agents/update', payload);
    useAlert(t('AGENT_MGMT.EDIT.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('AGENT_MGMT.EDIT.API.ERROR_MESSAGE')
    );
  }
};

const resetPassword = async () => {
  try {
    await Auth.resetPassword(agentCredentials.value);
    useAlert(t('AGENT_MGMT.EDIT.PASSWORD_RESET.ADMIN_SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('AGENT_MGMT.EDIT.PASSWORD_RESET.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="pageTitle" />
    <form class="w-full" @submit.prevent="editAgent">
      <div class="w-full">
        <label :class="{ error: v$.agentName.$error }">
          {{ $t('AGENT_MGMT.EDIT.FORM.NAME.LABEL') }}
          <input
            v-model="agentName"
            type="text"
            :placeholder="$t('AGENT_MGMT.EDIT.FORM.NAME.PLACEHOLDER')"
            @input="v$.agentName.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.selectedRoleId.$error }">
          {{ $t('AGENT_MGMT.EDIT.FORM.AGENT_TYPE.LABEL') }}
          <select v-model="selectedRoleId" @change="v$.selectedRoleId.$touch">
            <option v-for="role in roles" :key="role.id" :value="role.id">
              {{ role.label }}
            </option>
          </select>
          <span v-if="v$.selectedRoleId.$error" class="message">
            {{ $t('AGENT_MGMT.EDIT.FORM.AGENT_TYPE.ERROR') }}
          </span>
        </label>
      </div>

      <div v-if="isAdmin && selectedRole?.name === 'merchant'" class="w-full">
        <label :class="{ error: v$.agentLimit.$error }">
          {{ $t('AGENT_MGMT.EDIT.FORM.AGENT_LIMIT.LABEL') }}
          <input
            v-model.number="agentLimit"
            type="number"
            min="0"
            :placeholder="$t('AGENT_MGMT.EDIT.FORM.AGENT_LIMIT.PLACEHOLDER')"
            @input="v$.agentLimit.$touch"
          />
          <span v-if="v$.agentLimit.$error" class="message">
            {{ $t('AGENT_MGMT.EDIT.FORM.AGENT_LIMIT.ERROR') }}
          </span>
        </label>
      </div>

      <div v-if="isAdmin && selectedRole?.name === 'merchant'" class="w-full">
        <label>
          {{ $t('AGENT_MGMT.EDIT.FORM.EXPIRES_AT.LABEL') }}
          <input
            v-model="merchantExpiresAt"
            type="datetime-local"
            :placeholder="$t('AGENT_MGMT.EDIT.FORM.EXPIRES_AT.PLACEHOLDER')"
          />
        </label>
      </div>

      <div v-if="isAdmin && selectedRole?.name === 'merchant'" class="w-full">
        <label>
          {{ $t('AGENT_MGMT.EDIT.FORM.MERCHANT_STATUS.LABEL') }}
          <select v-model="merchantStatus">
            <option
              v-for="status in merchantStatuses"
              :key="status.value"
              :value="status.value"
            >
              {{ status.label }}
            </option>
          </select>
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.agentAvailability.$error }">
          {{ $t('PROFILE_SETTINGS.FORM.AVAILABILITY.LABEL') }}
          <select
            v-model="agentAvailability"
            @change="v$.agentAvailability.$touch"
          >
            <option
              v-for="status in availabilityStatuses"
              :key="status.value"
              :value="status.value"
            >
              {{ status.label }}
            </option>
          </select>
          <span v-if="v$.agentAvailability.$error" class="message">
            {{ $t('AGENT_MGMT.EDIT.FORM.AGENT_AVAILABILITY.ERROR') }}
          </span>
        </label>
      </div>

      <div v-if="provider !== 'saml'" class="w-full">
        <label :class="{ error: v$.agentPassword.$error }">
          {{ $t('AGENT_MGMT.EDIT.FORM.PASSWORD.LABEL') }}
          <input
            v-model="agentPassword"
            type="password"
            :placeholder="$t('AGENT_MGMT.EDIT.FORM.PASSWORD.PLACEHOLDER')"
            @input="v$.agentPassword.$touch"
          />
          <span v-if="v$.agentPassword.$error" class="message">
            {{ $t('AGENT_MGMT.EDIT.FORM.PASSWORD.ERROR') }}
          </span>
        </label>
      </div>

      <div v-if="provider !== 'saml'" class="w-full">
        <label :class="{ error: v$.agentPasswordConfirmation.$error }">
          {{ $t('AGENT_MGMT.EDIT.FORM.PASSWORD_CONFIRMATION.LABEL') }}
          <input
            v-model="agentPasswordConfirmation"
            type="password"
            :placeholder="
              $t('AGENT_MGMT.EDIT.FORM.PASSWORD_CONFIRMATION.PLACEHOLDER')
            "
            @input="v$.agentPasswordConfirmation.$touch"
          />
          <span v-if="v$.agentPasswordConfirmation.$error" class="message">
            {{ $t('AGENT_MGMT.EDIT.FORM.PASSWORD_CONFIRMATION.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex flex-row justify-start w-full gap-2 px-0 py-2">
        <div class="w-[50%] ltr:text-left rtl:text-right">
          <Button
            v-if="provider !== 'saml' && isAdmin"
            ghost
            type="button"
            icon="i-lucide-lock-keyhole"
            class="!px-2"
            :label="$t('AGENT_MGMT.EDIT.PASSWORD_RESET.ADMIN_RESET_BUTTON')"
            @click.prevent="resetPassword"
          />
        </div>
        <div class="w-[50%] flex justify-end items-center gap-2">
          <Button
            faded
            slate
            type="reset"
            :label="$t('AGENT_MGMT.EDIT.CANCEL_BUTTON_TEXT')"
            @click.prevent="emit('close')"
          />
          <Button
            type="submit"
            :label="$t('AGENT_MGMT.EDIT.FORM.SUBMIT')"
            :disabled="v$.$invalid || uiFlags.isUpdating"
            :is-loading="uiFlags.isUpdating"
          />
        </div>
      </div>
    </form>
  </div>
</template>
