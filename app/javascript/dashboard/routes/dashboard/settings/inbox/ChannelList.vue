<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';

import { useAccount } from 'dashboard/composables/useAccount';

import ChannelItem from 'dashboard/components/widgets/ChannelItem.vue';

const { t } = useI18n();
const router = useRouter();
const { accountId, currentAccount } = useAccount();

const globalConfig = useMapGetter('globalConfig/get');

const enabledFeatures = ref({});

const hasTiktokConfigured = computed(() => {
  return window.chatwootConfig?.tiktokAppId;
});

const channelSections = computed(() => {
  const { apiChannelName } = globalConfig.value;
  const nativeChannels = [
    {
      key: 'website',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WEBSITE.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WEBSITE.DESCRIPTION'),
      icon: 'i-woot-website',
      badgeLabel: t('INBOX_MGMT.ADD.AUTH.BADGES.NATIVE'),
    },
    {
      key: 'facebook',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.FACEBOOK.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.FACEBOOK.DESCRIPTION'),
      icon: 'i-woot-messenger',
      badgeLabel: t('INBOX_MGMT.ADD.AUTH.BADGES.NATIVE'),
    },
    {
      key: 'whatsapp',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP.DESCRIPTION'),
      icon: 'i-woot-whatsapp',
      badgeLabel: t('INBOX_MGMT.ADD.AUTH.BADGES.NATIVE'),
    },
    {
      key: 'sms',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.SMS.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.SMS.DESCRIPTION'),
      icon: 'i-woot-sms',
      badgeLabel: t('INBOX_MGMT.ADD.AUTH.BADGES.NATIVE'),
    },
    {
      key: 'email',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.EMAIL.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.EMAIL.DESCRIPTION'),
      icon: 'i-woot-mail',
      badgeLabel: t('INBOX_MGMT.ADD.AUTH.BADGES.NATIVE'),
    },
    {
      key: 'telegram',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TELEGRAM.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TELEGRAM.DESCRIPTION'),
      icon: 'i-woot-telegram',
      badgeLabel: t('INBOX_MGMT.ADD.AUTH.BADGES.NATIVE'),
    },
    {
      key: 'line',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.LINE.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.LINE.DESCRIPTION'),
      icon: 'i-woot-line',
      badgeLabel: t('INBOX_MGMT.ADD.AUTH.BADGES.NATIVE'),
    },
    {
      key: 'instagram',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.INSTAGRAM.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.INSTAGRAM.DESCRIPTION'),
      icon: 'i-woot-instagram',
      badgeLabel: t('INBOX_MGMT.ADD.AUTH.BADGES.NATIVE'),
    },
  ];

  if (hasTiktokConfigured.value) {
    nativeChannels.push({
      key: 'tiktok',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TIKTOK.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TIKTOK.DESCRIPTION'),
      icon: 'i-woot-tiktok',
      badgeLabel: t('INBOX_MGMT.ADD.AUTH.BADGES.NATIVE'),
    });
  }

  nativeChannels.push({
    key: 'voice',
    title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.VOICE.TITLE'),
    description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.VOICE.DESCRIPTION'),
    icon: 'i-ri-phone-fill',
    badgeLabel: t('INBOX_MGMT.ADD.AUTH.BADGES.NATIVE'),
  });

  const middlewareChannels = [
    {
      key: 'api',
      title: apiChannelName || t('INBOX_MGMT.ADD.AUTH.CHANNEL.API.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.API.DESCRIPTION'),
      icon: 'i-woot-api',
      badgeLabel: t('INBOX_MGMT.ADD.AUTH.BADGES.API'),
    },
    {
      key: 'linkedin',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.LINKEDIN.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.LINKEDIN.DESCRIPTION'),
      icon: 'i-ri-linkedin-box-fill',
      badgeLabel: t('INBOX_MGMT.ADD.AUTH.BADGES.API'),
    },
  ];

  return [
    {
      key: 'native',
      title: t('INBOX_MGMT.ADD.AUTH.SECTIONS.NATIVE.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.SECTIONS.NATIVE.DESCRIPTION'),
      channels: nativeChannels,
    },
    {
      key: 'api',
      title: t('INBOX_MGMT.ADD.AUTH.SECTIONS.API.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.SECTIONS.API.DESCRIPTION'),
      channels: middlewareChannels,
    },
  ];
});

const initializeEnabledFeatures = async () => {
  enabledFeatures.value = currentAccount.value.features;
};

const initChannelAuth = channel => {
  const params = {
    sub_page: channel,
    accountId: accountId.value,
  };
  router.push({ name: 'settings_inboxes_page_channel', params });
};

onMounted(() => {
  initializeEnabledFeatures();
});
</script>

<template>
  <div class="w-full p-8 overflow-auto">
    <div class="flex flex-col max-w-4xl gap-10">
      <section
        v-for="section in channelSections"
        :key="section.key"
        class="flex flex-col gap-4"
      >
        <div class="flex flex-col gap-1">
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ section.title }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ section.description }}
          </p>
        </div>
        <div class="grid grid-cols-1 xs:grid-cols-2 mx-0 gap-6 sm:grid-cols-3">
          <ChannelItem
            v-for="channel in section.channels"
            :key="channel.key"
            :channel="channel"
            :enabled-features="enabledFeatures"
            @channel-item-click="initChannelAuth"
          />
        </div>
      </section>
    </div>
  </div>
</template>
