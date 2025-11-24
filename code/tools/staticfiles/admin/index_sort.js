document.addEventListener("DOMContentLoaded", function () {
    const dashboard = document.querySelector("#dashboard");

    if (!dashboard) {
        return;
    }

    dashboard.firstElementChild.style.display = "flex";
    dashboard.firstElementChild.style.flexDirection = "column";

    const module_names = Array.from(document.querySelectorAll("a.section")).map(
        (a) =>
            a.parentElement.parentElement.parentElement.className.match(
                /app-(.*)?\s/
            )[1]
    );

    // console.log(module_names);

    const module_order = ["site", "module", "account", "customscript", "user"];

    const len = module_order.length;

    module_order.forEach((name, i) => {
        const el = dashboard.querySelector(`.app-${name}`);
        if (el) {
            el.style.order = -len + i;
        }
    });
});
