<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SelectInput from 'dashboard/components-next/select/Select.vue';

const model = defineModel({ type: String, default: 'first_message' });
const { t } = useI18n();
const options = computed(() => [
  {
    value: 'first_open',
    label: t('CHANNEL_GREETING_MODE.OPTIONS.FIRST_OPEN'),
  },
  {
    value: 'every_open',
    label: t('CHANNEL_GREETING_MODE.OPTIONS.EVERY_OPEN'),
  },
  {
    value: 'every_open_first_message',
    label: t('CHANNEL_GREETING_MODE.OPTIONS.EVERY_OPEN_FIRST_MESSAGE'),
  },
  {
    value: 'first_message',
    label: t('CHANNEL_GREETING_MODE.OPTIONS.FIRST_MESSAGE'),
  },
]);
</script>

<template>
  <label class="flex flex-col gap-2 mb-4">
    <span class="text-sm font-medium text-n-slate-12">
      {{ t('CHANNEL_GREETING_MODE.LABEL') }}
    </span>
    <SelectInput v-model="model" :options="options" />
    <span class="text-xs text-n-slate-11">
      {{ t('CHANNEL_GREETING_MODE.HELP_TEXT') }}
    </span>
  </label>
</template>
