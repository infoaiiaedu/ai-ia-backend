import ImageWidget from "./ImageWidget.svelte";

function readValue(element) {
    try {
        return JSON.parse(element.value);
    } catch (e) {
        return null;
    }
}

export default function createImageWidget(target, props = {}) {
    const name = props.name;

    const element = target.querySelector(`[name="${name}"]`);

    let value = readValue(element);

    element.remove();

    const app = new ImageWidget({
        target,
        props: {
            name,
            value,
            urlPrefix: props.url_prefix,
        },
    });

    return app;
}
