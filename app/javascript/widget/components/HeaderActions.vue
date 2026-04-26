<script>
import { mapGetters } from 'vuex';
import { IFrameHelper, RNHelper } from 'widget/helpers/utils';
import { popoutChatWindow } from '../helpers/popoutHelper';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import configMixin from 'widget/mixins/configMixin';
import { CONVERSATION_STATUS } from 'shared/constants/messages';
import { isStandaloneMode } from 'widget/helpers/urlParamsHelper';
import { CHATWOOT_ON_START_CONVERSATION } from '../constants/sdkEvents';

export default {
  name: 'HeaderActions',
  components: { FluentIcon },
  mixins: [configMixin],
  props: {
    showPopoutButton: {
      type: Boolean,
      default: false,
    },
    showEndConversationButton: {
      type: Boolean,
      default: true,
    },
  },
  computed: {
    ...mapGetters({
      conversationAttributes: 'conversationAttributes/getConversationParams',
      canUserEndConversation: 'appConfig/getCanUserEndConversation',
    }),
    canLeaveConversation() {
      return [
        CONVERSATION_STATUS.OPEN,
        CONVERSATION_STATUS.SNOOZED,
        CONVERSATION_STATUS.PENDING,
      ].includes(this.conversationStatus);
    },
    isIframe() {
      return IFrameHelper.isIFrame();
    },
    isRNWebView() {
      return RNHelper.isRNWebView();
    },
    isStandaloneWidget() {
      return isStandaloneMode(window.location.search);
    },
    showHeaderActions() {
      return (
        this.isIframe ||
        this.isRNWebView ||
        this.isStandaloneWidget ||
        this.hasWidgetOptions
      );
    },
    conversationStatus() {
      return this.conversationAttributes.status;
    },
    hasWidgetOptions() {
      return this.showPopoutButton || this.conversationStatus === 'open';
    },
    allowMessagesAfterResolved() {
      return window.chatwootWebChannel.allowMessagesAfterResolved;
    },
    shouldShowEndConversationButton() {
      return (
        this.canLeaveConversation &&
        this.canUserEndConversation &&
        this.hasEndConversationEnabled &&
        (this.showEndConversationButton || this.isStandaloneWidget)
      );
    },
    shouldShowStandaloneStartConversationButton() {
      return (
        this.isStandaloneWidget &&
        this.conversationStatus === CONVERSATION_STATUS.RESOLVED &&
        !this.allowMessagesAfterResolved
      );
    },
  },
  methods: {
    popoutWindow() {
      this.closeWindow();
      const {
        location: { origin },
        chatwootWebChannel: { websiteToken },
        authToken,
      } = window;
      popoutChatWindow(
        origin,
        websiteToken,
        this.$root.$i18n.locale,
        authToken
      );
    },
    closeWindow() {
      if (IFrameHelper.isIFrame()) {
        IFrameHelper.sendMessage({ event: 'closeWindow' });
      } else if (RNHelper.isRNWebView) {
        RNHelper.sendMessage({ type: 'close-widget' });
      }
    },
    resolveConversation() {
      this.$store.dispatch('conversation/resolveConversation');
    },
    startNewConversation() {
      this.$router.replace({ name: 'prechat-form' });
      IFrameHelper.sendMessage({
        event: 'onEvent',
        eventIdentifier: CHATWOOT_ON_START_CONVERSATION,
        data: { hasConversation: true },
      });
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <div v-if="showHeaderActions" class="actions flex items-center gap-3">
    <button
      v-if="shouldShowEndConversationButton"
      class="button transparent compact"
      :class="{
        'rounded-md px-3 py-1 text-sm font-medium leading-5':
          isStandaloneWidget,
      }"
      :title="$t('END_CONVERSATION')"
      @click="resolveConversation"
    >
      <template v-if="isStandaloneWidget">
        <span class="text-n-slate-12">{{ $t('END_CONVERSATION') }}</span>
      </template>
      <FluentIcon v-else icon="sign-out" size="22" class="text-n-slate-12" />
    </button>
    <button
      v-else-if="shouldShowStandaloneStartConversationButton"
      class="button transparent compact rounded-md px-3 py-1 text-sm font-medium leading-5"
      :title="$t('START_NEW_CONVERSATION')"
      @click="startNewConversation"
    >
      <span class="text-n-slate-12">{{ $t('START_NEW_CONVERSATION') }}</span>
    </button>
    <button
      v-if="showPopoutButton"
      class="button transparent compact new-window--button"
      @click="popoutWindow"
    >
      <FluentIcon icon="open" size="22" class="text-n-slate-12" />
    </button>
    <button
      class="button transparent compact close-button"
      :class="{
        'rn-close-button': isRNWebView,
      }"
      @click="closeWindow"
    >
      <FluentIcon icon="dismiss" size="24" class="text-n-slate-12" />
    </button>
  </div>
</template>

<style scoped lang="scss">
.actions {
  .close-button {
    display: none;
  }

  .rn-close-button {
    display: block !important;
  }
}
</style>
