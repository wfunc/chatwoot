<script setup>
import { computed } from 'vue';
import Banner from 'dashboard/components/ui/Banner.vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

const { accountId } = useAccount();
const { t } = useI18n();
const currentUser = useMapGetter('getCurrentUser');

const currentAccount = computed(() => {
  return (
    currentUser.value?.accounts?.find(account => {
      return Number(account.id) === Number(accountId.value);
    }) || {}
  );
});

const shouldShowBanner = computed(() => {
  const {
    role,
    parent_merchant_id: parentMerchantId,
    expiring_soon: expiringSoon,
    days_until_expiry: daysUntilExpiry,
  } = currentAccount.value;
  const merchantManaged = role === 'merchant' || !!parentMerchantId;

  return merchantManaged && expiringSoon && Number(daysUntilExpiry) > 0;
});

const bannerMessage = computed(() => {
  return t('APP_GLOBAL.MERCHANT_EXPIRY_PENDING', {
    count: currentAccount.value.days_until_expiry,
  });
});
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <Banner
    v-if="shouldShowBanner"
    color-scheme="warning"
    :banner-message="bannerMessage"
  />
</template>
