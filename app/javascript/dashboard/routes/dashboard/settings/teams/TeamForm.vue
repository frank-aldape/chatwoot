<script>
import { reactive } from 'vue';
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';

import FormInput from 'v3/components/Form/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import validations from './helpers/validations';
import ManagedCompaniesAPI from 'dashboard/api/managedCompanies';

const buildAssignment = assignment => {
  const {
    managed_company_id: managedCompanyId = '',
    inbox_ids: inboxIds = [],
    channel_keys: channelKeys = [],
  } = assignment || {};

  return {
    managedCompanyId: managedCompanyId || '',
    inboxIds,
    channelKeys,
    inboxSearchQuery: '',
    isCollapsed: Boolean(assignment),
  };
};

export default {
  components: {
    NextButton,
    FormInput,
    ChannelIcon,
  },
  props: {
    onSubmit: {
      type: Function,
      default: () => {},
    },
    submitInProgress: {
      type: Boolean,
      default: false,
    },
    formData: {
      type: Object,
      default: () => {},
    },
    submitButtonText: {
      type: String,
      default: '',
    },
  },
  setup(props) {
    const formData = props.formData || {};
    const {
      description = '',
      name: title = '',
      allow_auto_assign: allowAutoAssign = true,
      managed_company_assignments: managedCompanyAssignments = [],
    } = formData;

    const state = reactive({
      description,
      title,
      allowAutoAssign,
      managedCompanyAssignments:
        managedCompanyAssignments.length > 0
          ? managedCompanyAssignments.map(buildAssignment)
          : [],
    });

    const rules = validations;
    const v$ = useVuelidate(rules, state);
    return { state, v$ };
  },
  data() {
    return {
      managedCompanies: [],
      isManagedCompaniesLoading: false,
    };
  },
  computed: {
    ...mapGetters({
      inboxes: 'inboxes/getInboxes',
    }),
    inboxOptions() {
      return this.inboxes || [];
    },
    hasManagedCompanies() {
      return this.managedCompanies.length > 0;
    },
  },
  mounted() {
    this.fetchManagedCompanies();
    if (!this.inboxOptions.length) {
      this.$store.dispatch('inboxes/get');
    }
  },
  methods: {
    async fetchManagedCompanies() {
      this.isManagedCompaniesLoading = true;
      try {
        const response = await ManagedCompaniesAPI.get();
        this.managedCompanies = response.data || [];
      } finally {
        this.isManagedCompaniesLoading = false;
      }
    },
    addManagedCompanyAssignment() {
      this.state.managedCompanyAssignments.push(buildAssignment());
    },
    removeManagedCompanyAssignment(index) {
      this.state.managedCompanyAssignments.splice(index, 1);
    },
    toggleAssignmentCollapse(index) {
      const assignment = this.state.managedCompanyAssignments[index];
      assignment.isCollapsed = !assignment.isCollapsed;
    },
    onManagedCompanyChange(index) {
      const assignment = this.state.managedCompanyAssignments[index];
      const validInboxIds = this.inboxesForManagedCompany(
        assignment.managedCompanyId
      ).map(inbox => inbox.id);

      assignment.inboxIds = assignment.inboxIds.filter(inboxId =>
        validInboxIds.includes(inboxId)
      );
    },
    availableManagedCompanies(currentManagedCompanyId) {
      const selectedManagedCompanyIds = this.state.managedCompanyAssignments
        .map(({ managedCompanyId }) => managedCompanyId)
        .filter(Boolean);

      return this.managedCompanies.filter(({ id }) => {
        return (
          id === currentManagedCompanyId ||
          !selectedManagedCompanyIds.includes(id)
        );
      });
    },
    inboxesForManagedCompany(managedCompanyId) {
      return this.inboxOptions
        .filter(({ managed_company_id: companyId }) => {
          return companyId === managedCompanyId;
        })
        .sort((a, b) => {
          const channelCompare = this.inboxChannelLabel(a).localeCompare(
            this.inboxChannelLabel(b)
          );
          if (channelCompare !== 0) return channelCompare;
          return a.name.localeCompare(b.name);
        });
    },
    channelKey(inbox) {
      const keys = {
        'Channel::FacebookPage': 'facebook',
        'Channel::WebWidget': 'web_widget',
        'Channel::TwitterProfile': 'twitter',
        'Channel::Whatsapp': 'whatsapp',
        'Channel::Sms': 'sms',
        'Channel::Email': 'email',
        'Channel::Telegram': 'telegram',
        'Channel::Line': 'line',
        'Channel::Api': 'api',
        'Channel::Instagram': 'instagram',
        'Channel::Tiktok': 'tiktok',
        'Channel::Voice': 'voice',
      };

      if (inbox.channel_type === 'Channel::TwilioSms') {
        return inbox.medium === 'whatsapp' ? 'whatsapp' : 'twilio_sms';
      }
      return keys[inbox.channel_type] || inbox.channel_type;
    },
    channelOptionsForManagedCompany(managedCompanyId) {
      const groups = this.inboxesForManagedCompany(managedCompanyId).reduce(
        (acc, inbox) => {
          const key = this.channelKey(inbox);
          if (!acc[key]) {
            acc[key] = {
              key,
              label: this.inboxChannelLabel(inbox),
              inboxes: [],
            };
          }
          acc[key].inboxes.push(inbox);
          return acc;
        },
        {}
      );

      return Object.values(groups).sort((a, b) =>
        a.label.localeCompare(b.label)
      );
    },
    inboxChannelLabel(inbox) {
      const labels = {
        'Channel::FacebookPage': this.$t('INBOX_MGMT.CHANNELS.MESSENGER'),
        'Channel::WebWidget': this.$t('INBOX_MGMT.CHANNELS.WEB_WIDGET'),
        'Channel::TwitterProfile': this.$t(
          'INBOX_MGMT.CHANNELS.TWITTER_PROFILE'
        ),
        'Channel::Whatsapp': this.$t('INBOX_MGMT.CHANNELS.WHATSAPP'),
        'Channel::Sms': this.$t('INBOX_MGMT.CHANNELS.SMS'),
        'Channel::Email': this.$t('INBOX_MGMT.CHANNELS.EMAIL'),
        'Channel::Telegram': this.$t('INBOX_MGMT.CHANNELS.TELEGRAM'),
        'Channel::Line': this.$t('INBOX_MGMT.CHANNELS.LINE'),
        'Channel::Api': this.$t('INBOX_MGMT.CHANNELS.API'),
        'Channel::Instagram': this.$t('INBOX_MGMT.CHANNELS.INSTAGRAM'),
        'Channel::Tiktok': this.$t('INBOX_MGMT.CHANNELS.TIKTOK'),
        'Channel::Voice': this.$t('INBOX_MGMT.CHANNELS.VOICE'),
      };

      if (inbox.channel_type === 'Channel::TwilioSms') {
        return inbox.medium === 'whatsapp'
          ? this.$t('INBOX_MGMT.CHANNELS.WHATSAPP')
          : this.$t('INBOX_MGMT.CHANNELS.TWILIO_SMS');
      }

      return labels[inbox.channel_type] || inbox.channel_type;
    },
    inboxSourceLabel(inbox) {
      return (
        inbox.email ||
        inbox.phone_number ||
        inbox.website_url ||
        inbox.forward_to_email ||
        inbox.business_name ||
        ''
      );
    },
    inboxSubtitle(inbox) {
      return [this.inboxChannelLabel(inbox), this.inboxSourceLabel(inbox)]
        .filter(Boolean)
        .join(' - ');
    },
    managedCompanyOptionLabel(managedCompany) {
      return [managedCompany.name, managedCompany.authorized_domain]
        .filter(Boolean)
        .join(' - ');
    },
    selectedInboxCount(assignment) {
      return assignment.inboxIds.length;
    },
    selectedChannelCount(assignment, channelOption) {
      if (assignment.channelKeys.includes(channelOption.key)) {
        return channelOption.inboxes.length;
      }

      return channelOption.inboxes.filter(inbox =>
        assignment.inboxIds.includes(inbox.id)
      ).length;
    },
    isChannelSelected(assignment, channelOption) {
      return assignment.channelKeys.includes(channelOption.key);
    },
    toggleChannelInboxes(assignment, channelOption) {
      const channelInboxIds = channelOption.inboxes.map(inbox => inbox.id);
      if (this.isChannelSelected(assignment, channelOption)) {
        assignment.channelKeys = assignment.channelKeys.filter(
          channelKey => channelKey !== channelOption.key
        );
        assignment.inboxIds = assignment.inboxIds.filter(
          inboxId => !channelInboxIds.includes(inboxId)
        );
        return;
      }

      assignment.channelKeys = [
        ...new Set([...assignment.channelKeys, channelOption.key]),
      ];
      assignment.inboxIds = [
        ...new Set([...assignment.inboxIds, ...channelInboxIds]),
      ];
    },
    isAllCompanyInboxesSelected(assignment) {
      const companyInboxes = this.inboxesForManagedCompany(
        assignment.managedCompanyId
      );
      return (
        companyInboxes.length > 0 &&
        companyInboxes.every(inbox => assignment.inboxIds.includes(inbox.id))
      );
    },
    toggleAllCompanyInboxes(index) {
      const assignment = this.state.managedCompanyAssignments[index];
      const companyInboxes = this.inboxesForManagedCompany(
        assignment.managedCompanyId
      );
      const shouldClearSelection = this.isAllCompanyInboxesSelected(assignment);

      assignment.inboxIds = shouldClearSelection
        ? []
        : companyInboxes.map(inbox => inbox.id);
      assignment.channelKeys = shouldClearSelection
        ? []
        : this.channelOptionsForManagedCompany(assignment.managedCompanyId).map(
            channelOption => channelOption.key
          );
    },
    toggleInbox(assignment, inboxId) {
      const inbox = this.inboxOptions.find(({ id }) => id === inboxId);
      if (assignment.inboxIds.includes(inboxId)) {
        assignment.inboxIds = assignment.inboxIds.filter(id => id !== inboxId);
        if (inbox) {
          assignment.channelKeys = assignment.channelKeys.filter(
            channelKey => channelKey !== this.channelKey(inbox)
          );
        }
      } else {
        assignment.inboxIds = [...assignment.inboxIds, inboxId];
      }
    },
    filteredInboxesForAssignment(assignment) {
      const normalizedSearch = assignment.inboxSearchQuery.trim().toLowerCase();

      return this.inboxesForManagedCompany(assignment.managedCompanyId).filter(
        inbox => {
          const searchFields = [
            inbox.name,
            this.inboxChannelLabel(inbox),
            this.inboxSourceLabel(inbox),
            inbox.managed_company?.name,
            inbox.managed_company?.authorized_domain,
          ]
            .filter(Boolean)
            .join(' ')
            .toLowerCase();

          return searchFields.includes(normalizedSearch);
        }
      );
    },
    normalizedManagedCompanyAssignments() {
      return this.state.managedCompanyAssignments
        .filter(({ managedCompanyId }) => Boolean(managedCompanyId))
        .map(({ managedCompanyId, inboxIds, channelKeys }) => ({
          managed_company_id: managedCompanyId,
          inbox_ids: inboxIds,
          channel_keys: channelKeys,
        }));
    },
    handleSubmit() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      this.onSubmit({
        description: this.state.description,
        name: this.state.title,
        allow_auto_assign: this.state.allowAutoAssign,
        managed_company_assignments: this.normalizedManagedCompanyAssignments(),
      });
    },
  },
};
</script>

<template>
  <div class="flex-shrink-0 w-full">
    <form class="mx-0 grid gap-4" @submit.prevent="handleSubmit">
      <FormInput
        v-model="state.title"
        name="title"
        spacing="compact"
        :label="$t('TEAMS_SETTINGS.FORM.NAME.LABEL')"
        :placeholder="$t('TEAMS_SETTINGS.FORM.NAME.PLACEHOLDER')"
        :has-error="v$.title.$error"
        :error-message="v$.title.$error ? v$.title.$errors[0].$message : ''"
        @blur="v$.title.$touch"
      />
      <FormInput
        v-model="state.description"
        name="description"
        spacing="compact"
        :label="$t('TEAMS_SETTINGS.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('TEAMS_SETTINGS.FORM.DESCRIPTION.PLACEHOLDER')"
        :has-error="v$.description.$error"
        :error-message="
          v$.description.$error ? v$.description.$errors[0].$message : ''
        "
        @blur="v$.description.$touch"
      />
      <div class="w-full flex items-center gap-2">
        <input v-model="state.allowAutoAssign" type="checkbox" :value="true" />
        <label for="conversation_creation">
          {{ $t('TEAMS_SETTINGS.FORM.AUTO_ASSIGN.LABEL') }}
        </label>
      </div>
      <div class="grid gap-3 rounded-lg border border-n-weak p-4">
        <div class="flex items-start justify-between gap-3">
          <div>
            <p class="mb-1 text-sm font-medium text-n-slate-12">
              {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.TITLE') }}
            </p>
            <p class="mb-0 text-sm text-n-slate-11">
              {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.DESCRIPTION') }}
            </p>
          </div>
          <NextButton
            type="button"
            size="sm"
            slate
            :label="$t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.ADD')"
            @click="addManagedCompanyAssignment"
          />
        </div>

        <p
          v-if="isManagedCompaniesLoading"
          class="mb-0 text-sm text-n-slate-11"
        >
          {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.LOADING') }}
        </p>
        <p
          v-else-if="!hasManagedCompanies"
          class="mb-0 text-sm text-n-slate-11"
        >
          {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.EMPTY') }}
        </p>

        <div
          v-for="(assignment, index) in state.managedCompanyAssignments"
          :key="`${assignment.managedCompanyId || 'new'}-${index}`"
          class="grid gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-3"
        >
          <div class="grid gap-2 md:grid-cols-[minmax(0,1fr)_auto]">
            <label class="grid gap-2 text-sm font-medium text-n-slate-12">
              {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.COMPANY_LABEL') }}
              <select
                v-model="assignment.managedCompanyId"
                class="h-10 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
                @change="onManagedCompanyChange(index)"
              >
                <option value="">
                  {{
                    $t(
                      'TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.COMPANY_PLACEHOLDER'
                    )
                  }}
                </option>
                <option
                  v-for="managedCompany in availableManagedCompanies(
                    assignment.managedCompanyId
                  )"
                  :key="managedCompany.id"
                  :value="managedCompany.id"
                >
                  {{ managedCompanyOptionLabel(managedCompany) }}
                </option>
              </select>
            </label>

            <div class="flex items-end">
              <NextButton
                type="button"
                size="sm"
                slate
                :label="$t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.REMOVE')"
                @click="removeManagedCompanyAssignment(index)"
              />
            </div>
          </div>

          <div class="grid gap-2">
            <div
              class="flex flex-col gap-2 md:flex-row md:items-center md:justify-between"
            >
              <div>
                <p class="mb-0 text-sm font-medium text-n-slate-12">
                  {{
                    $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.INBOXES_LABEL')
                  }}
                </p>
                <p class="mb-0 text-xs text-n-slate-11">
                  {{
                    $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.SELECTED_COUNT', {
                      selected: selectedInboxCount(assignment),
                      total: inboxesForManagedCompany(
                        assignment.managedCompanyId
                      ).length,
                    })
                  }}
                </p>
              </div>
              <div class="flex items-center gap-2">
                <NextButton
                  type="button"
                  size="sm"
                  slate
                  :disabled="!assignment.managedCompanyId"
                  :label="
                    isAllCompanyInboxesSelected(assignment)
                      ? $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.CLEAR_ALL')
                      : $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.SELECT_ALL')
                  "
                  @click="toggleAllCompanyInboxes(index)"
                />
                <NextButton
                  v-if="assignment.managedCompanyId"
                  type="button"
                  size="sm"
                  slate
                  :icon="
                    assignment.isCollapsed
                      ? 'i-lucide-chevron-down'
                      : 'i-lucide-chevron-up'
                  "
                  @click="toggleAssignmentCollapse(index)"
                />
              </div>
            </div>

            <div
              v-if="!assignment.managedCompanyId"
              class="rounded-lg border border-n-weak bg-n-alpha-1 p-3 text-sm text-n-slate-11"
            >
              {{
                $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.SELECT_COMPANY_FIRST')
              }}
            </div>

            <div
              v-else-if="
                inboxesForManagedCompany(assignment.managedCompanyId).length ===
                0
              "
              class="rounded-lg border border-n-weak bg-n-alpha-1 p-3 text-sm text-n-slate-11"
            >
              {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.NO_INBOXES') }}
            </div>

            <div
              v-else-if="!assignment.isCollapsed"
              class="grid gap-3 rounded-lg border border-n-weak bg-n-background p-3"
            >
              <div
                v-if="assignment.managedCompanyId"
                class="flex flex-wrap gap-2"
              >
                <button
                  v-for="channelOption in channelOptionsForManagedCompany(
                    assignment.managedCompanyId
                  )"
                  :key="channelOption.key"
                  type="button"
                  class="rounded-md border px-3 py-1.5 text-xs font-medium"
                  :class="
                    isChannelSelected(assignment, channelOption)
                      ? 'border-n-brand bg-n-brand/10 text-n-brand'
                      : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2'
                  "
                  @click="toggleChannelInboxes(assignment, channelOption)"
                >
                  {{
                    $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.CHANNEL_PRESET', {
                      channel: channelOption.label,
                      selected: selectedChannelCount(assignment, channelOption),
                      total: channelOption.inboxes.length,
                    })
                  }}
                </button>
              </div>

              <input
                v-if="assignment.managedCompanyId"
                v-model="assignment.inboxSearchQuery"
                type="search"
                class="h-10 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12"
                :placeholder="
                  $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.SEARCH_INBOXES')
                "
              />

              <div class="grid max-h-72 gap-2 overflow-y-auto">
                <p
                  v-if="
                    assignment.managedCompanyId &&
                    filteredInboxesForAssignment(assignment).length === 0
                  "
                  class="mb-0 rounded-lg bg-n-alpha-1 p-3 text-sm text-n-slate-11"
                >
                  {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.NO_MATCHES') }}
                </p>

                <label
                  v-for="inbox in filteredInboxesForAssignment(assignment)"
                  :key="inbox.id"
                  class="flex cursor-pointer items-start gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-3 hover:bg-n-alpha-2"
                >
                  <input
                    type="checkbox"
                    class="mt-1"
                    :checked="assignment.inboxIds.includes(inbox.id)"
                    @change="toggleInbox(assignment, inbox.id)"
                  />
                  <ChannelIcon
                    class="mt-0.5 size-4 text-n-slate-10"
                    :inbox="inbox"
                  />
                  <span class="min-w-0 flex-1">
                    <span
                      class="block truncate text-sm font-medium text-n-slate-12"
                    >
                      {{ inbox.name }}
                    </span>
                    <span class="block truncate text-xs text-n-slate-11">
                      {{ inboxSubtitle(inbox) }}
                    </span>
                  </span>
                </label>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="flex flex-row justify-end gap-2 py-2 px-0 w-full">
        <div class="w-full">
          <NextButton
            type="submit"
            :label="submitButtonText"
            :disabled="v$.title.$invalid || submitInProgress"
            :is-loading="submitInProgress"
          />
        </div>
      </div>
    </form>
  </div>
</template>
