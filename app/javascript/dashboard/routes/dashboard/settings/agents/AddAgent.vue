<script setup>
import { ref, computed } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required, email, requiredIf, minLength } from '@vuelidate/validators';
import Button from 'dashboard/components-next/button/Button.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();
const { isAdmin, isMerchant } = useAdmin();

const agentName = ref('');
const agentEmail = ref('');
const selectedRoleId = ref('agent');
const merchantAgentLimit = ref(null);
const merchantExpiresAt = ref('');
const agentPassword = ref('');
const agentPasswordConfirmation = ref('');

const rules = {
  agentName: { required },
  agentEmail: { required, email },
  selectedRoleId: { required },
  agentPassword: {
    required: requiredIf(() => !!agentPasswordConfirmation.value),
    minLength: minLength(6),
  },
  agentPasswordConfirmation: {
    required: requiredIf(() => !!agentPassword.value),
    minLength: minLength(6),
    isEqPassword: value => !value || value === agentPassword.value,
  },
  merchantAgentLimit: {
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
  agentEmail,
  selectedRoleId,
  agentPassword,
  agentPasswordConfirmation,
  merchantAgentLimit,
});

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

const addAgent = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const payload = {
      name: agentName.value,
      email: agentEmail.value,
    };

    if (agentPassword.value) {
      payload.password = agentPassword.value;
      payload.password_confirmation = agentPasswordConfirmation.value;
    }

    if (selectedRole.value.name === 'merchant') {
      payload.role = 'merchant';
      payload.agent_limit = Number(merchantAgentLimit.value);
      if (merchantExpiresAt.value) {
        payload.merchant_expires_at = merchantExpiresAt.value;
      }
    } else if (selectedRole.value.name.startsWith('custom_')) {
      payload.custom_role_id = selectedRole.value.id;
    } else {
      payload.role = selectedRole.value.name;
    }

    await store.dispatch('agents/create', payload);
    useAlert(t('AGENT_MGMT.ADD.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    const attributes = error?.response?.data?.attributes || [];
    const defaultErrorMessage =
      error?.response?.status === 422 && !attributes.includes('base')
        ? t('AGENT_MGMT.ADD.API.EXIST_MESSAGE')
        : t('AGENT_MGMT.ADD.API.ERROR_MESSAGE');

    useAlert(parseAPIErrorResponse(error) || defaultErrorMessage);
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('AGENT_MGMT.ADD.TITLE')"
      :header-content="$t('AGENT_MGMT.ADD.DESC')"
    />
    <form class="flex flex-col items-start w-full" @submit.prevent="addAgent">
      <div class="w-full">
        <label :class="{ error: v$.agentName.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.NAME.LABEL') }}
          <input
            v-model="agentName"
            type="text"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.NAME.PLACEHOLDER')"
            @input="v$.agentName.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.selectedRoleId.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.AGENT_TYPE.LABEL') }}
          <select v-model="selectedRoleId" @change="v$.selectedRoleId.$touch">
            <option v-for="role in roles" :key="role.id" :value="role.id">
              {{ role.label }}
            </option>
          </select>
          <span v-if="v$.selectedRoleId.$error" class="message">
            {{ $t('AGENT_MGMT.ADD.FORM.AGENT_TYPE.ERROR') }}
          </span>
        </label>
      </div>

      <div v-if="isAdmin && selectedRole?.name === 'merchant'" class="w-full">
        <label :class="{ error: v$.merchantAgentLimit.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.AGENT_LIMIT.LABEL') }}
          <input
            v-model.number="merchantAgentLimit"
            type="number"
            min="0"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.AGENT_LIMIT.PLACEHOLDER')"
            @input="v$.merchantAgentLimit.$touch"
          />
          <span v-if="v$.merchantAgentLimit.$error" class="message">
            {{ $t('AGENT_MGMT.ADD.FORM.AGENT_LIMIT.ERROR') }}
          </span>
        </label>
      </div>

      <div v-if="isAdmin && selectedRole?.name === 'merchant'" class="w-full">
        <label>
          {{ $t('AGENT_MGMT.ADD.FORM.EXPIRES_AT.LABEL') }}
          <input
            v-model="merchantExpiresAt"
            type="datetime-local"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.EXPIRES_AT.PLACEHOLDER')"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.agentEmail.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.EMAIL.LABEL') }}
          <input
            v-model="agentEmail"
            type="email"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.EMAIL.PLACEHOLDER')"
            @input="v$.agentEmail.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.agentPassword.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.PASSWORD.LABEL') }}
          <input
            v-model="agentPassword"
            type="password"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.PASSWORD.PLACEHOLDER')"
            @input="v$.agentPassword.$touch"
          />
          <span v-if="v$.agentPassword.$error" class="message">
            {{ $t('AGENT_MGMT.ADD.FORM.PASSWORD.ERROR') }}
          </span>
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.agentPasswordConfirmation.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.PASSWORD_CONFIRMATION.LABEL') }}
          <input
            v-model="agentPasswordConfirmation"
            type="password"
            :placeholder="
              $t('AGENT_MGMT.ADD.FORM.PASSWORD_CONFIRMATION.PLACEHOLDER')
            "
            @input="v$.agentPasswordConfirmation.$touch"
          />
          <span v-if="v$.agentPasswordConfirmation.$error" class="message">
            {{ $t('AGENT_MGMT.ADD.FORM.PASSWORD_CONFIRMATION.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <Button
          faded
          slate
          type="reset"
          :label="$t('AGENT_MGMT.ADD.CANCEL_BUTTON_TEXT')"
          @click.prevent="emit('close')"
        />
        <Button
          type="submit"
          :label="$t('AGENT_MGMT.ADD.FORM.SUBMIT')"
          :disabled="v$.$invalid || uiFlags.isCreating"
          :is-loading="uiFlags.isCreating"
        />
      </div>
    </form>
  </div>
</template>
