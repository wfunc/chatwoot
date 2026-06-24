<script setup>
import { ref, computed, onMounted } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, requiredIf } from '@vuelidate/validators';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Auth from '../../../../api/auth';
import AgentAPI from '../../../../api/agents';
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
  maxActiveClients: {
    type: Number,
    default: null,
  },
});

const emit = defineEmits(['close']);
const MAX_ACTIVE_CLIENTS = 25;

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
const maxActiveClients = ref(props.maxActiveClients);
const agentPassword = ref('');
const agentPasswordConfirmation = ref('');
const activeClients = ref([]);
const isFetchingActiveClients = ref(false);
const revokingClientId = ref('');

const isValidMaxActiveClients = value => {
  if (value === null || value === '') return true;

  const numericValue = Number(value);
  return (
    Number.isInteger(numericValue) &&
    numericValue >= 1 &&
    numericValue <= MAX_ACTIVE_CLIENTS
  );
};

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
  maxActiveClients: { isValid: isValidMaxActiveClients },
};

const v$ = useVuelidate(rules, {
  agentName,
  selectedRoleId,
  agentAvailability,
  agentPassword,
  agentPasswordConfirmation,
  agentLimit,
  maxActiveClients,
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

const formatTimestamp = timestamp => {
  if (!timestamp) return t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.EMPTY_VALUE');

  const date = new Date(Number(timestamp) * 1000);
  if (Number.isNaN(date.getTime())) {
    return t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.EMPTY_VALUE');
  }

  return date.toLocaleString();
};

const shortClient = client => {
  if (!client) return '';
  if (client.length <= 16) return client;

  return `${client.slice(0, 8)}...${client.slice(-6)}`;
};

const isCurrentClient = client => Auth.getAuthData()?.client === client;

const fetchActiveClients = async () => {
  isFetchingActiveClients.value = true;
  try {
    const response = await AgentAPI.getActiveClients(props.id);
    activeClients.value = response.data;
  } catch (error) {
    useAlert(t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.API.ERROR_MESSAGE'));
  } finally {
    isFetchingActiveClients.value = false;
  }
};

const revokeActiveClient = async client => {
  revokingClientId.value = client;
  try {
    await AgentAPI.deleteActiveClient(props.id, client);
    activeClients.value = activeClients.value.filter(
      activeClient => activeClient.client !== client
    );
    useAlert(t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.API.ERROR_MESSAGE'));
  } finally {
    revokingClientId.value = '';
  }
};

onMounted(fetchActiveClients);

const editAgent = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const payload = {
      id: props.id,
      name: agentName.value,
      availability: agentAvailability.value,
      max_active_clients:
        maxActiveClients.value === null || maxActiveClients.value === ''
          ? null
          : Number(maxActiveClients.value),
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
        <label :class="{ error: v$.maxActiveClients.$error }">
          {{ $t('AGENT_MGMT.EDIT.FORM.MAX_ACTIVE_CLIENTS.LABEL') }}
          <input
            v-model.number="maxActiveClients"
            type="number"
            min="1"
            :max="MAX_ACTIVE_CLIENTS"
            :placeholder="
              $t('AGENT_MGMT.EDIT.FORM.MAX_ACTIVE_CLIENTS.PLACEHOLDER')
            "
            @input="v$.maxActiveClients.$touch"
          />
          <span v-if="v$.maxActiveClients.$error" class="message">
            {{ $t('AGENT_MGMT.EDIT.FORM.MAX_ACTIVE_CLIENTS.ERROR') }}
          </span>
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

      <div class="w-full py-3">
        <div class="flex items-center justify-between gap-2 mb-2">
          <h3 class="m-0 text-sm font-medium text-n-slate-12">
            {{ $t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.TITLE') }}
          </h3>
          <Button
            ghost
            slate
            xs
            type="button"
            icon="i-lucide-refresh-cw"
            :disabled="isFetchingActiveClients"
            :is-loading="isFetchingActiveClients"
            @click.prevent="fetchActiveClients"
          />
        </div>
        <div
          v-if="!isFetchingActiveClients && activeClients.length === 0"
          class="text-sm text-n-slate-11"
        >
          {{ $t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.EMPTY') }}
        </div>
        <div v-else class="overflow-x-auto border rounded-md border-n-weak">
          <table class="w-full text-sm">
            <thead class="bg-n-slate-2 text-n-slate-11">
              <tr>
                <th class="px-3 py-2 font-medium text-left">
                  {{ $t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.CLIENT') }}
                </th>
                <th class="px-3 py-2 font-medium text-left">
                  {{ $t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.IP') }}
                </th>
                <th class="px-3 py-2 font-medium text-left">
                  {{ $t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.LOGIN_TIME') }}
                </th>
                <th class="px-3 py-2 font-medium text-left">
                  {{ $t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.LAST_SEEN') }}
                </th>
                <th class="px-3 py-2 font-medium text-left">
                  {{ $t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.DEVICE') }}
                </th>
                <th class="px-3 py-2 font-medium text-right">
                  {{ $t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.ACTIONS') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="activeClient in activeClients"
                :key="activeClient.client"
                class="border-t border-n-weak"
              >
                <td class="px-3 py-2 text-n-slate-12 whitespace-nowrap">
                  <span>{{ shortClient(activeClient.client) }}</span>
                  <span
                    v-if="isCurrentClient(activeClient.client)"
                    class="ml-1 text-xs text-n-slate-11"
                  >
                    {{ $t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.CURRENT') }}
                  </span>
                </td>
                <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
                  {{
                    activeClient.ip ||
                    $t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.EMPTY_VALUE')
                  }}
                </td>
                <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
                  {{ formatTimestamp(activeClient.created_at) }}
                </td>
                <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
                  {{ formatTimestamp(activeClient.last_seen_at) }}
                </td>
                <td class="max-w-56 px-3 py-2 text-n-slate-11">
                  <span class="block truncate">
                    {{
                      activeClient.user_agent ||
                      $t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.EMPTY_VALUE')
                    }}
                  </span>
                </td>
                <td class="px-3 py-2 text-right whitespace-nowrap">
                  <Button
                    ghost
                    ruby
                    xs
                    type="button"
                    icon="i-lucide-log-out"
                    :label="$t('AGENT_MGMT.EDIT.ACTIVE_CLIENTS.KICK')"
                    :disabled="revokingClientId === activeClient.client"
                    :is-loading="revokingClientId === activeClient.client"
                    @click.prevent="revokeActiveClient(activeClient.client)"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
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
