import glob from "glob";
import path from "path";
import fs from "fs";

import svelte from "rollup-plugin-svelte";
import commonjs from "@rollup/plugin-commonjs";
import resolve from "@rollup/plugin-node-resolve";
import livereload from "rollup-plugin-livereload";
import { terser } from "rollup-plugin-terser";
import sveltePreprocess from "svelte-preprocess";

import sass from "sass";

const postcss = require("postcss");
const postcssConfig = require("./postcss.config");

const production = !process.env.ROLLUP_WATCH;

const DIST_DIR = "./static/dwidgets";

function sassPlugin() {
    const fromCss = "./scss/main.scss";
    const toCss = path.join(DIST_DIR, "bundle.css");

    return {
        name: "sass",
        load() {
            glob.sync("./scss/**/*.scss").forEach((filename) => {
                this.addWatchFile(filename);
            });
        },
        generateBundle() {
            sass.render(
                {
                    file: fromCss,
                    outputStyle: "compressed",
                    sourceMap: !production,
                },
                (err, result) => {
                    if (err) {
                        return console.error(err);
                    }

                    postcss(postcssConfig.plugins)
                        .process(result.css, {
                            from: fromCss,
                            to: toCss,
                        })
                        .then((result) => {
                            fs.writeFile(toCss, result.css, (err) => {
                                if (err) return console.log(err);
                            });
                        });
                }
            );
        },
    };
}

export default {
    input: "src/main.js",
    output: {
        sourcemap: !production,
        format: "iife",
        name: "widgets",
        file: "static/dwidgets/bundle.js",
    },
    plugins: [
        sassPlugin(),
        svelte({
            preprocess: sveltePreprocess({ sourceMap: !production }),
            compilerOptions: {
                dev: !production,
            },
        }),
        resolve({
            browser: true,
            dedupe: ["svelte"],
        }),
        commonjs(),
        !production && livereload({ watch: "static", port: 3176 }),
        production && terser(),
    ],
    watch: {
        clearScreen: false,
    },
};
