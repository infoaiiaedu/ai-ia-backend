<script>
    import { flip } from "svelte/animate";

    export let name;
    export let value;
    export let urlPrefix;

    let prefix = "dynamic-gallery-widget";

    let imgItems = [];
    let widgetValue = "";

    if (value) {
        imgItems = value.map((v) => {
            return { ...v };
        });
    }

    $: {
        widgetValue = JSON.stringify(
            imgItems
                .sort((a, b) => (a < b ? -1 : 1))
                .map((e) => {
                    return {
                        url: e.url,
                        title: e.title,
                    };
                })
        );
    }

    const getSrc = (url) => (url.startsWith("http") ? url : "/media/" + url);

    const openMediaManager = () => {
        const media_manager_url = window.MEDIA_MANAGER_URL;

        const mm = new MManager({
            media_manager_url,
            usetinymce: false,
            autoclose: false,
        });

        mm.callback = (detail) => {
            let val = detail.replace(urlPrefix, "");

            const exists = !!imgItems.find((e) => e.url == val);

            if (exists) {
                return;
            }

            const items = imgItems;
            items.splice(0, 0, { url: val, title: "" });
            imgItems = items;
        };

        window.addEventListener("message", function (event) {
            mm.eventListener(event);
        });

        mm.active = true;
        mm.open();
    };

    const removeCard = (index) => {

        const items = imgItems;
        items.splice(index, 1);
        imgItems = items;
    };

    let hovering = false;

    const dragstart = (event, i) => {
        event.dataTransfer.effectAllowed = "move";
        event.dataTransfer.dropEffect = "move";

        const start = i;

        event.dataTransfer.setData("text/plain", start);
    };

    const drop = (event, target) => {
        event.dataTransfer.dropEffect = "move";

        const start = parseInt(event.dataTransfer.getData("text/plain"));
        const newTracklist = imgItems;

        if (start < target) {
            newTracklist.splice(target + 1, 0, newTracklist[start]);
            newTracklist.splice(start, 1);
        } else {
            newTracklist.splice(target, 0, newTracklist[start]);
            newTracklist.splice(start + 1, 1);
        }
        imgItems = newTracklist;
        hovering = null;
    };
</script>

<div class="{prefix}-wrapper">
    <div class="{prefix}-control">
        <input
            class="{prefix}-btn"
            type="button"
            value="არჩევა"
            on:click={openMediaManager}
        />
    </div>

    <div class="{prefix}-items">
        {#each imgItems as item, index (item.url)}
            <div
                class="{prefix}-item"
                animate:flip={{ duration: 500 }}
                draggable="true"
                on:dragstart={(event) => dragstart(event, index)}
                on:drop|preventDefault={(event) => drop(event, index)}
                ondragover="return false"
                on:dragenter={() => (hovering = index)}
                class:is-active={hovering === index}
            >
                <img
                    class="{prefix}-item-img"
                    src={getSrc(item.url)}
                    alt={item.title}
                    tabindex="-1"
                />

                <div class="{prefix}-item-overlay" />

                <div class="{prefix}-item-controls">
                    <button
                        title="წაშლა"
                        type="button"
                        class="{prefix}-item-remove"
                        on:click={() => removeCard(index)}>&times;</button
                    >
                    <input type="text" value={item.url} readonly />
                    <textarea bind:value={item.title} />
                </div>
            </div>
        {/each}
    </div>
</div>
<textarea hidden {name} value={widgetValue} />
