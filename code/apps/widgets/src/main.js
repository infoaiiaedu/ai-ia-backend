import createImageWidget from "./widgets/image";
import createVideoWidget from "./widgets/video";
import createAudioWidget from "./widgets/audio";
import createGalleryWidget from "./widgets/gallery";

export const mapping = {
    image: createImageWidget,
    video: createVideoWidget,
    audio: createAudioWidget,
    gallery: createGalleryWidget,
};

document.addEventListener("DOMContentLoaded", () => {
    document.querySelectorAll("div[django_widget]").forEach((e) => {
        const widget_name = e.getAttribute("django_widget");

        if (widget_name in mapping) {
            mapping[widget_name](e, { ...e.dataset, parent: e });
        }
    });
});
