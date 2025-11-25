<script>
    import { onMount } from "svelte";

    export let name;
    export let value;
    export let urlPrefix = "/media/uploads/videos/";

    let vidValue = value?.url || "";
    let posterValue = value?.poster || "";
    let widgetValue = "";

    let videoEl;
    let canvasEl;

    // Update widgetValue whenever vidValue or posterValue changes
    $: widgetValue = vidValue
        ? JSON.stringify({ url: vidValue, poster: posterValue })
        : "null";

    const openVideoManager = () => {
        const mm = new MManager({ media_manager_url: window.MEDIA_MANAGER_URL });

        mm.callback = async (detail) => {
            vidValue = detail;

            // Generate poster client-side after video loads
            setTimeout(generatePoster, 100);
        };

        window.addEventListener("message", (event) => mm.eventListener(event));
        mm.active = true;
        mm.open();
    };

    function generatePoster() {
        if (!videoEl) return;

        // Create canvas same size as video
        canvasEl.width = videoEl.videoWidth;
        canvasEl.height = videoEl.videoHeight;

        const ctx = canvasEl.getContext("2d");
        ctx.drawImage(videoEl, 0, 0, canvasEl.width, canvasEl.height);

        // Convert canvas to data URL (JPEG)
        posterValue = canvasEl.toDataURL("image/jpeg");
    }
</script>

<div class="dynamic-video-widget-wrapper">
    <div class="dynamic-video-widget">
        <input type="text" bind:value={vidValue} readonly />
        <input type="button" value="არჩევა ვიდეო" on:click={openVideoManager} />
    </div>

    {#if vidValue}
        <video
            bind:this={videoEl}
            src={vidValue}
            controls
            on:loadeddata={generatePoster}
            style="max-width:500px; display:block; margin-top:10px;"
        ></video>

        {#if posterValue}
            <img
                src={posterValue}
                alt="Poster"
                style="max-width:150px; display:block; margin-top:5px;"
            />
        {/if}
    {/if}

    <!-- Hidden canvas to generate poster -->
    <canvas bind:this={canvasEl} style="display:none;"></canvas>

    <textarea hidden {name} value={widgetValue}></textarea>
</div>
