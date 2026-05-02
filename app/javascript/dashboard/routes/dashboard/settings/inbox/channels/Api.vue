<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import router from '../../../../index';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ManagedCompanyNamingFields from '../components/ManagedCompanyNamingFields.vue';

const shouldBeWebhookUrl = (value = '') =>
  value ? value.startsWith('http') : true;

export default {
  components: {
    PageHeader,
    NextButton,
    ManagedCompanyNamingFields,
  },
  props: {
    pageHeaderTitle: {
      type: String,
      default: '',
    },
    pageHeaderDescription: {
      type: String,
      default: '',
    },
    channelLabel: {
      type: String,
      default: '',
    },
    submitButtonLabel: {
      type: String,
      default: '',
    },
    errorMessage: {
      type: String,
      default: '',
    },
    defaultWebhookUrl: {
      type: String,
      default: '',
    },
    additionalAttributes: {
      type: Object,
      default: () => ({}),
    },
    integrationSlot: {
      type: String,
      default: '',
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      channelName: '',
      managedCompanyId: null,
      hasManagedCompanySlotConflict: false,
      functionLabel: '',
      webhookUrl: this.defaultWebhookUrl,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
    resolvedPageHeaderTitle() {
      return (
        this.pageHeaderTitle || this.$t('INBOX_MGMT.ADD.API_CHANNEL.TITLE')
      );
    },
    resolvedPageHeaderDescription() {
      return (
        this.pageHeaderDescription || this.$t('INBOX_MGMT.ADD.API_CHANNEL.DESC')
      );
    },
    resolvedChannelLabel() {
      return this.channelLabel || this.$t('INBOX_MGMT.CHANNELS.API');
    },
    resolvedSubmitButtonLabel() {
      return (
        this.submitButtonLabel ||
        this.$t('INBOX_MGMT.ADD.API_CHANNEL.SUBMIT_BUTTON')
      );
    },
    resolvedErrorMessage() {
      return (
        this.errorMessage ||
        this.$t('INBOX_MGMT.ADD.API_CHANNEL.API.ERROR_MESSAGE')
      );
    },
  },
  validations: {
    channelName: { required },
    webhookUrl: { shouldBeWebhookUrl },
  },
  methods: {
    async createChannel() {
      if (this.hasManagedCompanySlotConflict) {
        useAlert(this.$t('INBOX_MGMT.ADD.MANAGED_COMPANY.SLOT_CONFLICT_TITLE'));
        return;
      }

      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const apiChannel = await this.$store.dispatch('inboxes/createChannel', {
          name: this.channelName?.trim(),
          managed_company_id: this.managedCompanyId,
          channel: {
            type: 'api',
            webhook_url: this.webhookUrl,
            additional_attributes: this.additionalAttributes,
          },
        });

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: apiChannel.id,
          },
        });
      } catch (error) {
        useAlert(this.resolvedErrorMessage);
      }
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="resolvedPageHeaderTitle"
      :header-content="resolvedPageHeaderDescription"
    />
    <form
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createChannel()"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.channelName.$error }">
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.CHANNEL_NAME.LABEL') }}
          <input
            v-model="channelName"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.API_CHANNEL.CHANNEL_NAME.PLACEHOLDER')
            "
            @blur="v$.channelName.$touch"
          />
          <span v-if="v$.channelName.$error" class="message">{{
            $t('INBOX_MGMT.ADD.API_CHANNEL.CHANNEL_NAME.ERROR')
          }}</span>
        </label>
      </div>

      <ManagedCompanyNamingFields
        v-model:managed-company-id="managedCompanyId"
        v-model:has-slot-conflict="hasManagedCompanySlotConflict"
        v-model:function-label="functionLabel"
        v-model:inbox-name="channelName"
        :channel-label="resolvedChannelLabel"
        :integration-slot="integrationSlot"
        class="mb-4"
      />

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.webhookUrl.$error }">
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.WEBHOOK_URL.LABEL') }}
          <input
            v-model="webhookUrl"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.API_CHANNEL.WEBHOOK_URL.PLACEHOLDER')
            "
            @blur="v$.webhookUrl.$touch"
          />
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.WEBHOOK_URL.SUBTITLE') }}
        </p>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="uiFlags.isCreating"
          :disabled="hasManagedCompanySlotConflict"
          type="submit"
          solid
          blue
          :label="resolvedSubmitButtonLabel"
        />
      </div>
    </form>
  </div>
</template>
