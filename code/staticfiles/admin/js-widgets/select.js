(function () {
    if (typeof django == "undefined") {
        return;
    }

    const $ = django.jQuery;

    class SelectTwo extends HTMLElement {
        constructor() {
            super();

            const select = this.querySelector("select");

            this.append(select);

            $(select).select2 && $(select).select2();
        }
    }

    customElements.define("select-two", SelectTwo);
})();
