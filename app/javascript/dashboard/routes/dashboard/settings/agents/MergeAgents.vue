<script setup>
import { ref, computed, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const agentList = useMapGetter('agents/getAgents');
const uiFlags = useMapGetter('agents/getUIFlags');
const currentUserId = useMapGetter('getCurrentUserID');

const baseAgentId = ref(null);
const mergeeAgentId = ref(null);
const prevailingEmail = ref('');

const findAgent = id => agentList.value.find(agent => agent.id === id);
const agentLabel = agent => `${agent.name} \u2014 ${agent.email}`;

const baseAgent = computed(() => findAgent(baseAgentId.value));
const mergeeAgent = computed(() => findAgent(mergeeAgentId.value));

const baseOptions = computed(() =>
  agentList.value.filter(agent => agent.id !== mergeeAgentId.value)
);

// Your own account can never be the absorbed one: it would delete the session in use.
const mergeeOptions = computed(() =>
  agentList.value.filter(
    agent => agent.id !== baseAgentId.value && agent.id !== currentUserId.value
  )
);

const emailOptions = computed(() =>
  [baseAgent.value, mergeeAgent.value].filter(Boolean).map(agent => agent.email)
);

watch(emailOptions, options => {
  if (!options.includes(prevailingEmail.value)) {
    prevailingEmail.value = baseAgent.value?.email || '';
  }
});

const isValid = computed(
  () => baseAgent.value && mergeeAgent.value && prevailingEmail.value
);

const mergeAgents = async () => {
  try {
    await store.dispatch('agents/merge', {
      baseAgentId: baseAgentId.value,
      mergeeAgentId: mergeeAgentId.value,
      email: prevailingEmail.value,
    });
    useAlert(t('AGENT_MGMT.MERGE.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    const message = parseAPIErrorResponse(error);
    useAlert(
      typeof message === 'string'
        ? message
        : t('AGENT_MGMT.MERGE.API.ERROR_MESSAGE')
    );
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('AGENT_MGMT.MERGE.TITLE')"
      :header-content="$t('AGENT_MGMT.MERGE.DESC')"
    />
    <form class="w-full" @submit.prevent="mergeAgents">
      <div class="w-full">
        <label>
          {{ $t('AGENT_MGMT.MERGE.FORM.BASE_AGENT.LABEL') }}
          <select v-model="baseAgentId">
            <option :value="null" disabled>
              {{ $t('AGENT_MGMT.MERGE.FORM.BASE_AGENT.PLACEHOLDER') }}
            </option>
            <option
              v-for="agent in baseOptions"
              :key="agent.id"
              :value="agent.id"
            >
              {{ agentLabel(agent) }}
            </option>
          </select>
        </label>
        <p class="mt-0 mb-4 text-sm text-n-slate-11">
          {{ $t('AGENT_MGMT.MERGE.FORM.BASE_AGENT.HELP') }}
        </p>
      </div>

      <div class="w-full">
        <label>
          {{ $t('AGENT_MGMT.MERGE.FORM.MERGEE_AGENT.LABEL') }}
          <select v-model="mergeeAgentId">
            <option :value="null" disabled>
              {{ $t('AGENT_MGMT.MERGE.FORM.MERGEE_AGENT.PLACEHOLDER') }}
            </option>
            <option
              v-for="agent in mergeeOptions"
              :key="agent.id"
              :value="agent.id"
            >
              {{ agentLabel(agent) }}
            </option>
          </select>
        </label>
        <p class="mt-0 mb-4 text-sm text-n-slate-11">
          {{ $t('AGENT_MGMT.MERGE.FORM.MERGEE_AGENT.HELP') }}
        </p>
      </div>

      <div v-if="emailOptions.length" class="w-full">
        <label>
          {{ $t('AGENT_MGMT.MERGE.FORM.EMAIL.LABEL') }}
        </label>
        <p class="mt-0 mb-2 text-sm text-n-slate-11">
          {{ $t('AGENT_MGMT.MERGE.FORM.EMAIL.HELP') }}
        </p>
        <div class="flex flex-col gap-1 mb-4">
          <label
            v-for="option in emailOptions"
            :key="option"
            class="flex items-center gap-2 mb-0 font-normal"
          >
            <input
              v-model="prevailingEmail"
              type="radio"
              :value="option"
              class="m-0"
            />
            {{ option }}
          </label>
        </div>
      </div>

      <div
        v-if="isValid"
        class="w-full p-3 mb-4 text-sm rounded-lg bg-n-alpha-2 text-n-slate-11"
      >
        {{
          $t('AGENT_MGMT.MERGE.SUMMARY', {
            mergee: mergeeAgent.email,
            base: baseAgent.name,
            email: prevailingEmail,
          })
        }}
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <Button
          faded
          slate
          type="reset"
          :label="$t('AGENT_MGMT.MERGE.CANCEL_BUTTON_TEXT')"
          @click.prevent="emit('close')"
        />
        <Button
          type="submit"
          ruby
          :label="$t('AGENT_MGMT.MERGE.FORM.SUBMIT')"
          :disabled="!isValid || uiFlags.isUpdating"
          :is-loading="uiFlags.isUpdating"
        />
      </div>
    </form>
  </div>
</template>
