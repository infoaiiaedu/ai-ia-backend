<script>
    export let name;
    export let value;

    let prefix = "dynamic-video-widget";
    let rootElement;
    let vidElement;

    let vidValue = "";
    let widgetValue = "";

    if (value) {
        vidValue = value?.url || "";
    }

    $: {
        if (!vidValue) {
            widgetValue = "null";
        } else {
            widgetValue = JSON.stringify({
                url: vidValue,
            });
        }
    }

    const openVideoManager = (target) => {
        const video_manager_url = window.VIDEO_MANAGER_URL + "/audio";
        const video_manager_key = window.VIDEO_MANAGER_KEY;

        const vm = new VideoManager({
            video_manager_url,
            video_manager_key,
        });

        window.addEventListener("message", function (event) {
            vm.eventListener(event);
        });

        vm.callback = (detail) => {
            console.log(detail);

            let duration = detail.duration || "00";
            duration = duration
                .split(":")
                .reverse()
                .reduce((s, t, i) => (s += Number(t) * 60 ** i), 0);

            let el = document.querySelector("#id_duration");
            if (el) el.value = duration;

            let vid_source_host = "https://video.ambebi.ge/";
            let base_url = vid_source_host + detail.url.replace("//", "/");

            let video_url = base_url + ".mp3";
            vidValue = video_url;
        };
        vm.open();
    };
</script>

<div class="{prefix}-wrapper" bind:this={rootElement}>
    <div class={prefix}>
        <input
            class="{prefix}-inp"
            type="text"
            id={"id_" + name}
            bind:value={vidValue}
        />
        <input
            class="{prefix}-btn"
            type="button"
            value="არჩევა"
            on:click={openVideoManager}
        />
    </div>

    {#if vidValue}
        <div class="{prefix}-container">
            <audio bind:this={vidElement} src={vidValue} controls />
        </div>
    {/if}

    <textarea hidden {name} value={widgetValue} />
</div>
