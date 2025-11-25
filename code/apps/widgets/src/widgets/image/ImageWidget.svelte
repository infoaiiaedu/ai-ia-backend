<script>
    import { onMount } from "svelte";

    export let name;
    export let value;
    export let urlPrefix;

    let prefix = "dynamic-image-widget";
    let imgElement;
    let rectElement;

    let valid = false;

    let inpValue = "";
    let widgetValue = "";
    let point = { x: 50, y: 50 };

    $: imgValue =
        inpValue.startsWith("http") || inpValue.startsWith("//")
            ? inpValue
            : urlPrefix + inpValue;

    if (value) {
        inpValue = value?.url || "";
        point.x = value?.point?.[0] || 50;
        point.y = value?.point?.[1] || 50;
    }

    $: {
        if (!inpValue) {
            widgetValue = "null";
        } else {
            widgetValue = JSON.stringify({
                url: inpValue,
                point: [point.x, point.y],
            });
        }
    }

    const onImageLoad = () => {
        valid = true;
        rectElement.style.width = imgElement.width + "px";
        rectElement.style.height = imgElement.height + "px";
    };

    const changePoint = (e) => {
        const rect = rectElement.getBoundingClientRect();
        point.x = Math.floor((100 * (e.clientX - rect.left)) / rect.width);
        point.y = Math.floor((100 * (e.clientY - rect.top)) / rect.height);
    };

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

        mm.active = true;
        mm.open();
    };
</script>

<div class="{prefix}-wrapper">
    <div class={prefix}>
        <input
            class="{prefix}-inp"
            type="text"
            id={"id_" + name}
            bind:value={inpValue}
        />
        <!-- Only this button remains -->
        <input
            class="{prefix}-btn"
            type="button"
            value="არჩევა"
            on:click={openMediaManager}
        />
    </div>

    {#if inpValue}
        <div>{point.x}% {point.y}%</div>
        <div
            class="{prefix}-preview"
            style="visibility: {valid ? 'visible' : 'hidden'};"
        >
            <div class="{prefix}-rect" bind:this={rectElement}>
                <img
                    class="{prefix}-img"
                    bind:this={imgElement}
                    on:load={onImageLoad}
                    on:error={onImageError}
                    src={imgValue}
                    alt=""
                />

                <div class="{prefix}-overlay" on:click={changePoint} />

                <div
                    class="{prefix}-point"
                    style="left: {point.x}%; top: {point.y}%;"
                />
            </div>
        </div>
    {/if}

    <textarea hidden {name} value={widgetValue} />
</div>
