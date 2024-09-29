const asdf = await WebAssembly.instantiateStreaming(fetch("zig-out/bin/webgame_v0.wasm"), {
    env: {
        consoleLog: (arg) => console.log(arg),
    }
});
asdf.instance.exports.buggy(2);
