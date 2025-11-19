import Widget from "./AudioWidget.svelte";

function readValue(element) {
    try {
        return JSON.parse(element.value);
    } catch (e) {
        return null;
    }
}

export default function createWidget(target, props = {}) {
    const name = props.name;

    const element = target.querySelector(`[name="${name}"]`);

    let value = readValue(element);

    element.remove();

    const app = new Widget({
        target,
        props: {
            name,
            value,
        },
    });

    return app;
}
