class VideoManager {
    constructor({
        video_manager_url,
        video_manager_key,
        width = 1000,
        height = 640,
    }) {
        this.self_url =
            window.location.protocol + "//" + window.location.host + "/";
        this.video_manager_url = video_manager_url;
        this.video_manager_key = video_manager_key;

        this.message_key = "videomanager";

        this.width = width;
        this.height = height;

        this.win = null;
        this.callback = null;

        this._connected = false;

        this.url = [
            this.video_manager_url,
            `?site=${this.self_url}`,
            `&key=${this.video_manager_key}`,
            `&model=${this.message_key}`,
        ].join("");
    }

    open() {
        this.win = window.open(
            this.url,
            "Video Manager",
            `width=${this.width},height=${this.height}`
        );
    }

    close() {
        !!this.win && this.win.close();

        this.win = null;
        this.callback = null;
    }

    get connected() {
        return this._connected;
    }

    set connected(val) {
        this._connected = val;
        if (!val) {
            this.win = null;
            this.callback = null;
        }
    }

    postMessage(data) {
        !!this.win &&
            this.win.postMessage(
                {
                    action: this.message_key,
                    ...data,
                },
                this.video_manager_url
            );
    }

    eventListener(event) {
        let data = event.data;

        if (data.key !== this.message_key) {
            return false;
        }

        this.insertFile(data);
    }

    insertFile(detail) {
        if (this.callback) {
            this.callback(detail);
            this.close();
        }
    }
}
