const canvas_ctx = document.querySelector("#ctx_canvas");
const ctx = canvas_ctx.getContext("2d");
canvas_ctx.style.imageRendering = "pixelated";

const asdf = await WebAssembly.instantiateStreaming(fetch("zig-out/bin/webgame_v0.wasm"));
const wasm_exports = asdf.instance.exports;
const wasm_memory = new Uint8Array(wasm_exports.memory.buffer);

// Automatically set canvas size as defined in `checkerboard.zig`
const checkerboardSize = wasm_exports.getCheckerboardSize();
canvas_ctx.width = checkerboardSize;
canvas_ctx.height = checkerboardSize;

const context = canvas_ctx.getContext("2d");
const imageData = context.createImageData(canvas_ctx.width, canvas_ctx.height);
context.clearRect(0, 0, canvas_ctx.width, canvas_ctx.height);

const getDarkValue = () => {
    return Math.floor(Math.random() * 100);
};
const getLightValue = () => {
    return Math.floor(Math.random() * 127) + 127;
};

const drawCheckerboard = () => {
    wasm_exports.colorCheckerboard(
        getDarkValue(),
        getDarkValue(),
        getDarkValue(),
        getLightValue(),
        getLightValue(),
        getLightValue()
    );

    const bufferOffset = wasm_exports.getCheckerboardBufferPointer();
    const imageDataArray = wasm_memory.slice(
        bufferOffset,
        bufferOffset + checkerboardSize * checkerboardSize * 4
    );
    console.log(bufferOffset);
    console.log(wasm_exports.memory);

    imageData.data.set(imageDataArray);

    context.clearRect(0, 0, canvas_ctx.width, canvas_ctx.height);
    context.putImageData(imageData, 0, 0);
};

drawCheckerboard();
