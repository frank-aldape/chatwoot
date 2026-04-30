<script setup>
import { computed, reactive, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import FormInput from 'v3/components/Form/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import ManagedCompaniesAPI from 'dashboard/api/managedCompanies';

const { t } = useI18n();
const store = useStore();

const managedCompanies = ref([]);
const isLoading = ref(false);
const isSubmitting = ref(false);
const showDeletePopup = ref(false);
const selectedManagedCompany = ref({});

const form = reactive({
  id: null,
  name: '',
  authorizedDomain: '',
  status: 'active',
  dnsStatus: 'unchecked',
  spfValid: false,
  dkimValid: false,
});

const isEditing = computed(() => Boolean(form.id));
const inboxes = useMapGetter('inboxes/getInboxes');
const teams = useMapGetter('teams/getTeams');

const teamNamesById = computed(() =>
  (teams.value || []).reduce((acc, team) => {
    acc[team.id] = team.name;
    return acc;
  }, {})
);

const inboxNamesById = computed(() =>
  (inboxes.value || []).reduce((acc, inbox) => {
    acc[inbox.id] = inbox.name;
    return acc;
  }, {})
);

const resolvedManagedCompanies = computed(() =>
  managedCompanies.value.map(managedCompany => ({
    ...managedCompany,
    inboxNames: (managedCompany.inbox_ids || [])
      .map(id => inboxNamesById.value[id])
      .filter(Boolean),
    teamNames: (managedCompany.team_ids || [])
      .map(id => teamNamesById.value[id])
      .filter(Boolean),
  }))
);

const resetForm = () => {
  form.id = null;
  form.name = '';
  form.authorizedDomain = '';
  form.status = 'active';
  form.dnsStatus = 'unchecked';
  form.spfValid = false;
  form.dkimValid = false;
};

const fetchManagedCompanies = async () => {
  isLoading.value = true;
  try {
    const response = await ManagedCompaniesAPI.get();
    managedCompanies.value = response.data || [];
  } catch (error) {
    useAlert(t('MANAGED_COMPANIES_SETTINGS.API.LIST_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const submitForm = async () => {
  isSubmitting.value = true;
  const payload = {
    managed_company: {
      name: form.name,
      authorized_domain: form.authorizedDomain,
      status: form.status,
      dns_status: form.dnsStatus,
      spf_valid: form.spfValid,
      dkim_valid: form.dkimValid,
    },
  };

  try {
    if (isEditing.value) {
      await ManagedCompaniesAPI.update(form.id, payload);
      useAlert(t('MANAGED_COMPANIES_SETTINGS.API.UPDATE_SUCCESS'));
    } else {
      await ManagedCompaniesAPI.create(payload);
      useAlert(t('MANAGED_COMPANIES_SETTINGS.API.CREATE_SUCCESS'));
    }

    resetForm();
    fetchManagedCompanies();
  } catch (error) {
    useAlert(
      isEditing.value
        ? t('MANAGED_COMPANIES_SETTINGS.API.UPDATE_ERROR')
        : t('MANAGED_COMPANIES_SETTINGS.API.CREATE_ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};

const editManagedCompany = managedCompany => {
  form.id = managedCompany.id;
  form.name = managedCompany.name;
  form.authorizedDomain = managedCompany.authorized_domain;
  form.status = managedCompany.status;
  form.dnsStatus = managedCompany.dns_status;
  form.spfValid = managedCompany.spf_valid;
  form.dkimValid = managedCompany.dkim_valid;
};

const openDelete = managedCompany => {
  selectedManagedCompany.value = managedCompany;
  showDeletePopup.value = true;
};

const closeDelete = () => {
  selectedManagedCompany.value = {};
  showDeletePopup.value = false;
};

const confirmDeletion = async () => {
  try {
    await ManagedCompaniesAPI.delete(selectedManagedCompany.value.id);
    useAlert(t('MANAGED_COMPANIES_SETTINGS.API.DELETE_SUCCESS'));
    if (form.id === selectedManagedCompany.value.id) {
      resetForm();
    }
    fetchManagedCompanies();
  } catch (error) {
    useAlert(t('MANAGED_COMPANIES_SETTINGS.API.DELETE_ERROR'));
  } finally {
    closeDelete();
  }
};

onMounted(() => {
  fetchManagedCompanies();
  store.dispatch('inboxes/get');
  store.dispatch('teams/get');
});
</script>

<template>
  <div class="flex-1 overflow-auto">
    <BaseSettingsHeader
      :title="$t('MANAGED_COMPANIES_SETTINGS.HEADER')"
      :description="$t('MANAGED_COMPANIES_SETTINGS.DESCRIPTION')"
    />

    <div class="mt-6 grid gap-6 xl:grid-cols-[minmax(0,380px)_minmax(0,1fr)]">
      <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
        <div class="mb-4">
          <h2 class="mb-1 text-base font-medium text-n-slate-12">
            {{
              isEditing
                ? $t('MANAGED_COMPANIES_SETTINGS.FORM.EDIT_TITLE')
                : $t('MANAGED_COMPANIES_SETTINGS.FORM.CREATE_TITLE')
            }}
          </h2>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ $t('MANAGED_COMPANIES_SETTINGS.FORM.DESCRIPTION') }}
          </p>
        </div>

        <form class="grid gap-4" @submit.prevent="submitForm">
          <FormInput
            v-model="form.name"
            name="managed-company-name"
            spacing="compact"
            :label="$t('MANAGED_COMPANIES_SETTINGS.FORM.NAME_LABEL')"
            :placeholder="
              $t('MANAGED_COMPANIES_SETTINGS.FORM.NAME_PLACEHOLDER')
            "
          />
          <FormInput
            v-model="form.authorizedDomain"
            name="managed-company-domain"
            spacing="compact"
            :label="$t('MANAGED_COMPANIES_SETTINGS.FORM.DOMAIN_LABEL')"
            :placeholder="
              $t('MANAGED_COMPANIES_SETTINGS.FORM.DOMAIN_PLACEHOLDER')
            "
          />

          <label class="grid gap-2 text-sm font-medium text-n-slate-12">
            {{ $t('MANAGED_COMPANIES_SETTINGS.FORM.STATUS_LABEL') }}
            <select
              v-model="form.status"
              class="h-10 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
            >
              <option value="active">
                {{ $t('MANAGED_COMPANIES_SETTINGS.FORM.STATUS_ACTIVE') }}
              </option>
              <option value="inactive">
                {{ $t('MANAGED_COMPANIES_SETTINGS.FORM.STATUS_INACTIVE') }}
              </option>
            </select>
          </label>

          <label class="grid gap-2 text-sm font-medium text-n-slate-12">
            {{ $t('MANAGED_COMPANIES_SETTINGS.FORM.DNS_STATUS_LABEL') }}
            <select
              v-model="form.dnsStatus"
              class="h-10 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
            >
              <option value="unchecked">
                {{ $t('MANAGED_COMPANIES_SETTINGS.FORM.DNS_STATUS_UNCHECKED') }}
              </option>
              <option value="valid">
                {{ $t('MANAGED_COMPANIES_SETTINGS.FORM.DNS_STATUS_VALID') }}
              </option>
              <option value="invalid">
                {{ $t('MANAGED_COMPANIES_SETTINGS.FORM.DNS_STATUS_INVALID') }}
              </option>
            </select>
          </label>

          <div class="grid gap-3 rounded-lg border border-n-weak p-3">
            <label class="flex items-center gap-2 text-sm text-n-slate-12">
              <input v-model="form.spfValid" type="checkbox" />
              <span>{{ $t('MANAGED_COMPANIES_SETTINGS.FORM.SPF_VALID') }}</span>
            </label>
            <label class="flex items-center gap-2 text-sm text-n-slate-12">
              <input v-model="form.dkimValid" type="checkbox" />
              <span>{{
                $t('MANAGED_COMPANIES_SETTINGS.FORM.DKIM_VALID')
              }}</span>
            </label>
          </div>

          <div class="flex gap-2">
            <NextButton
              type="submit"
              :label="
                isEditing
                  ? $t('MANAGED_COMPANIES_SETTINGS.FORM.UPDATE')
                  : $t('MANAGED_COMPANIES_SETTINGS.FORM.CREATE')
              "
              :is-loading="isSubmitting"
            />
            <Button
              v-if="isEditing"
              type="button"
              slate
              :label="$t('MANAGED_COMPANIES_SETTINGS.FORM.CANCEL')"
              @click="resetForm"
            />
          </div>
        </form>
      </section>

      <section class="rounded-xl border border-n-weak bg-n-background">
        <woot-loading-state
          v-if="isLoading"
          :message="$t('MANAGED_COMPANIES_SETTINGS.LOADING')"
        />
        <div
          v-else-if="!managedCompanies.length"
          class="p-8 text-sm text-n-slate-11"
        >
          {{ $t('MANAGED_COMPANIES_SETTINGS.EMPTY') }}
        </div>
        <table v-else class="min-w-full divide-y divide-n-weak">
          <tbody class="divide-y divide-n-weak">
            <tr
              v-for="managedCompany in resolvedManagedCompanies"
              :key="managedCompany.id"
              class="align-top"
            >
              <td class="px-4 py-4">
                <div class="flex flex-col gap-1">
                  <span class="font-medium text-n-slate-12">
                    {{ managedCompany.name }}
                  </span>
                  <span class="text-sm text-n-slate-11">
                    {{ managedCompany.authorized_domain }}
                  </span>
                  <div class="flex flex-wrap gap-2 text-xs text-n-slate-11">
                    <span>
                      {{
                        $t('MANAGED_COMPANIES_SETTINGS.LIST.INBOX_COUNT', {
                          count: managedCompany.inbox_ids.length,
                        })
                      }}
                    </span>
                    <span>
                      {{
                        $t('MANAGED_COMPANIES_SETTINGS.LIST.TEAM_COUNT', {
                          count: managedCompany.team_ids.length,
                        })
                      }}
                    </span>
                    <span>
                      {{
                        $t('MANAGED_COMPANIES_SETTINGS.LIST.DNS_STATUS', {
                          status: managedCompany.dns_status,
                        })
                      }}
                    </span>
                    <span>
                      {{
                        $t('MANAGED_COMPANIES_SETTINGS.LIST.SPF_STATUS', {
                          status: managedCompany.spf_valid
                            ? $t('MANAGED_COMPANIES_SETTINGS.LIST.VERIFIED')
                            : $t('MANAGED_COMPANIES_SETTINGS.LIST.PENDING'),
                        })
                      }}
                    </span>
                    <span>
                      {{
                        $t('MANAGED_COMPANIES_SETTINGS.LIST.DKIM_STATUS', {
                          status: managedCompany.dkim_valid
                            ? $t('MANAGED_COMPANIES_SETTINGS.LIST.VERIFIED')
                            : $t('MANAGED_COMPANIES_SETTINGS.LIST.PENDING'),
                        })
                      }}
                    </span>
                  </div>
                  <div class="mt-3 grid gap-3 text-sm">
                    <div class="grid gap-1">
                      <span class="font-medium text-n-slate-12">
                        {{
                          $t('MANAGED_COMPANIES_SETTINGS.LIST.INBOXES_LABEL')
                        }}
                      </span>
                      <div
                        v-if="managedCompany.inboxNames.length"
                        class="flex flex-wrap gap-2"
                      >
                        <span
                          v-for="inboxName in managedCompany.inboxNames"
                          :key="inboxName"
                          class="rounded-full bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-12"
                        >
                          {{ inboxName }}
                        </span>
                      </div>
                      <span v-else class="text-xs text-n-slate-11">
                        {{
                          $t(
                            'MANAGED_COMPANIES_SETTINGS.LIST.NO_INBOXES_ASSIGNED'
                          )
                        }}
                      </span>
                    </div>

                    <div class="grid gap-1">
                      <span class="font-medium text-n-slate-12">
                        {{ $t('MANAGED_COMPANIES_SETTINGS.LIST.TEAMS_LABEL') }}
                      </span>
                      <div
                        v-if="managedCompany.teamNames.length"
                        class="flex flex-wrap gap-2"
                      >
                        <span
                          v-for="teamName in managedCompany.teamNames"
                          :key="teamName"
                          class="rounded-full bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-12"
                        >
                          {{ teamName }}
                        </span>
                      </div>
                      <span v-else class="text-xs text-n-slate-11">
                        {{
                          $t(
                            'MANAGED_COMPANIES_SETTINGS.LIST.NO_TEAMS_ASSIGNED'
                          )
                        }}
                      </span>
                    </div>
                  </div>
                </div>
              </td>
              <td class="px-4 py-4 text-right">
                <div class="flex justify-end gap-2">
                  <Button
                    xs
                    slate
                    faded
                    icon="i-lucide-pencil"
                    :label="$t('MANAGED_COMPANIES_SETTINGS.LIST.EDIT')"
                    @click="editManagedCompany(managedCompany)"
                  />
                  <Button
                    xs
                    ruby
                    faded
                    icon="i-lucide-trash-2"
                    :label="$t('MANAGED_COMPANIES_SETTINGS.LIST.DELETE')"
                    @click="openDelete(managedCompany)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>

    <woot-confirm-delete-modal
      v-if="showDeletePopup"
      v-model:show="showDeletePopup"
      :title="$t('MANAGED_COMPANIES_SETTINGS.DELETE.TITLE')"
      :message="$t('MANAGED_COMPANIES_SETTINGS.DELETE.MESSAGE')"
      :confirm-text="$t('MANAGED_COMPANIES_SETTINGS.DELETE.CONFIRM')"
      :reject-text="$t('MANAGED_COMPANIES_SETTINGS.DELETE.CANCEL')"
      :confirm-value="selectedManagedCompany.name"
      :confirm-place-holder-text="
        $t('MANAGED_COMPANIES_SETTINGS.DELETE.PLACEHOLDER', {
          name: selectedManagedCompany.name,
        })
      "
      @on-confirm="confirmDeletion"
      @on-close="closeDelete"
    />
  </div>
</template>
