<script>
    export let name;
    export let value;
    export let urlPrefix = "/media/uploads/videos/"; // separate folder for videos

    let vidValue = value?.url || "";
    let posterValue = value?.poster || "";
    let widgetValue = "";

    $: widgetValue = vidValue
        ? JSON.stringify({
              url: vidValue,
              poster: posterValue || vidValue.replace(/\.(mp4|webm|ogg)$/, ".jpg"),
          })
        : "null";

    const openVideoManager = () => {
        const mm = new MManager({ media_manager_url: window.MEDIA_MANAGER_URL });

        mm.callback = (detail) => {
            // detail is the uploaded video path
            vidValue = detail;

            // automatically assign poster if empty
            if (!posterValue) {
                posterValue = detail.replace(/\.(mp4|webm|ogg)$/, ".jpg");
            }
        };

        window.addEventListener("message", (event) => mm.eventListener(event));

        mm.active = true;
        mm.open();
    };
</script>

<div class="dynamic-video-widget-wrapper">
    <div class="dynamic-video-widget">
        <input type="text" bind:value={vidValue} readonly />
        <input type="button" value="არჩევა" on:click={openVideoManager} />
    </div>

    {#if vidValue}
        <video src={vidValue} controls style="max-width:500; display:block; margin-top:10px;"></video>
        {#if posterValue}
            <img src={posterValue} alt="Poster" style="max-width:150px; display:block; margin-top:5px;" />
        {/if}
    {/if}

    <textarea hidden {name} value={widgetValue}></textarea>
</div>
