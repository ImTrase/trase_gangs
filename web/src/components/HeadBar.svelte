<script lang="ts">
  import CloseIcon from "virtual:icons/mdi/close";
  import ListIcon from "virtual:icons/mdi/view-dashboard";
  export let title = "Dashboard";
  export let subtitle = "Quick overview & actions";
  export let onClose: () => void = () => {};
</script>

<header class="header">
  <div class="title">
    <div class="title-ico"><ListIcon /></div>
    <div>
      <h1>{title}</h1>
      <p>{subtitle}</p>
    </div>
  </div>
  <div class="actions">
    <span class="esc">ESC</span>
    <button class="icon-btn" on:click={onClose} aria-label="Close"
      ><CloseIcon color="white" /></button
    >
  </div>
</header>
