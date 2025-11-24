<script>
    export let name;
    export let value;
<<<<<<< HEAD
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
=======
    export let urlPrefix;

    let prefix = "dynamic-video-widget";
    let rootElement;
    let imgElement;
    let vidElement;

    let valid = false;

    let inpValue = "";
    let vidValue = "";
    let widgetValue = "";

    let croploading = false;

    $: imgValue =
        inpValue.startsWith("http") || inpValue.startsWith("//")
            ? inpValue
            : urlPrefix + inpValue;

    if (value) {
        vidValue = value?.url || "";
        inpValue = value?.poster || "";
    }

    $: {
        if (!vidValue) {
            widgetValue = "null";
        } else {
            widgetValue = JSON.stringify({
                url: vidValue,
                poster: inpValue || vidValue.replace(/\.mp4$/, ".jpg"),
            });
        }
    }

    const onImageError = () => {
        valid = false;
    };

    const openMediaManager = () => {
        const media_manager_url = window.MEDIA_MANAGER_URL;

        const mm = new MManager({
            media_manager_url,
            usetinymce: false,
        });

        mm.callback = (detail) => {
            inpValue = detail.replace(urlPrefix, "");
            mm.active = false;
        };

        window.addEventListener("message", function (event) {
            mm.eventListener(event);
        });
>>>>>>> 582c3dc12a9409382079981e07f3d17f362746f3

        mm.active = true;
        mm.open();
    };
<<<<<<< HEAD
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
=======

    const openVideoManager = (target) => {
        const video_manager_url = window.VIDEO_MANAGER_URL;
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

            if (el) {
                el.value = duration;
            }

            let vid_source_host = "https://video.ambebi.ge/";

            let base_url = vid_source_host + detail.url.replace("//", "/");

            let video_url = base_url + ".mp4";
            let poster_url = base_url + ".jpg";

            vidValue = video_url;

            if (!inpValue) {
                inpValue = poster_url;
            }
        };
        vm.open();
    };

    async function cropImage() {
        vidElement.pause();

        croploading = true;

        const frameUrl = rootElement.parentElement.dataset.frame;
        const seconds = Math.floor(vidElement.currentTime);

        const formdata = new FormData();
        formdata.append("video-url", vidValue);
        formdata.append("seconds", seconds);

        const resp = await fetch(frameUrl, {
            method: "POST",
            body: formdata,
            headers: {
                "X-CSRFToken": document.querySelector('meta[name="csrftoken"]')
                    .content,
            },
        });

        const data = await resp.json();

        inpValue = data.url;

        const img_inp = document.querySelector("input#id_image");

        if (img_inp) {
            img_inp.value = data.url;
            img_inp.dispatchEvent(
                new Event("input", {
                    view: window,
                    bubbles: true,
                    cancelable: true,
                })
            );
        }

        croploading = false;
    }
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
        <input
            class="{prefix}-btn"
            type="button"
            value="მოჭრა"
            disabled={croploading}
            on:click={cropImage}
        />
        <input
            class="{prefix}-btn"
            type="button"
            value="სურათი"
            on:click={openMediaManager}
        />
    </div>

    <input
        hidden={!vidValue}
        class="{prefix}-inp poster"
        type="text"
        id={"id_" + name}
        bind:value={inpValue}
    />

    {#if vidValue}
        <div class="{prefix}-container">
            <video bind:this={vidElement} src={vidValue} controls />
            {#if inpValue}
                <img
                    bind:this={imgElement}
                    on:error={onImageError}
                    src={imgValue}
                />
            {/if}
        </div>
    {/if}

    <textarea hidden {name} value={widgetValue} />
>>>>>>> 582c3dc12a9409382079981e07f3d17f362746f3
</div>
