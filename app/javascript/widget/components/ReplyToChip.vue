<script>
export default {
  name: 'AgentMessage',
  props: {
    replyTo: {
      type: Object,
      default: () => {},
    },
  },
  data() {
    return {
      timeOutID: null,
    };
  },
  computed: {
    replyToAttachment() {
      if (!this.replyTo?.attachments?.length) {
        return '';
      }

      const [{ file_type: fileType } = {}] = this.replyTo.attachments;
      return this.$t(`ATTACHMENTS.${fileType}.CONTENT`);
    },
  },

  unmounted() {
    clearTimeout(this.timeOutID);
  },
  methods: {
    navigateTo(id) {
      const elementId = `cwmsg-${id}`;
      this.$nextTick(() => {
        const el = document.getElementById(elementId);
        el.scrollIntoView();
        el.classList.add('bg-n-slate-3', 'dark:bg-n-solid-3');
        this.timeOutID = setTimeout(() => {
          el.classList.remove('bg-n-slate-3', 'dark:bg-n-solid-3');
        }, 500);
      });
    },
  },
};
</script>

<template>
  <button
    class="px-1.5 py-0.5 rounded-md text-n-slate-11 bg-n-slate-4 opacity-60 hover:opacity-100 cursor-pointer flex items-center gap-1.5"
    @click="navigateTo(replyTo.id)"
  >
    <span class="i-lucide-reply size-3 flex-shrink-0" />
    <div class="truncate max-w-[8rem]">
      {{ replyTo.content || replyToAttachment }}
    </div>
  </button>
</template>
