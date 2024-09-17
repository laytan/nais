(function() {

	class NaisInterface {

		/**
	 	 * @param {WasmMemoryInterface} mem
	 	 */
		constructor(mem) {
			this.mem = mem;
		}

		getInterface() {
			const inputEl = document.getElementById("nais-input");
			if (inputEl) {
				inputEl.addEventListener("input", (e) => {
					if (e.inputType != "insertText") {
						return;
					}

					const textLength = new TextEncoder().encode(e.data).length;
					if (textLength <= 0) {
						return;
					}

					const textAddr = this.mem.exports.nais_input_buffer_resize(textLength);
					this.mem.storeString(textAddr, e.data);
					this.mem.exports.nais_input_buffer_ingest();
				});
			} else {
				console.warn("no nais-input element, Text input is not captured");
			}

			return {
				get_clipboard_text_raw: () => {
					if (!navigator.clipboard) {
						return;
					}

					navigator.clipboard.readText()
						.then(text => {
							const textLength = new TextEncoder().encode(text).length;

							const textAddr = this.mem.exports.nais_get_clipboard_text_raw_callback(textLength);
							this.mem.storeString(textAddr, text);
						})
						.catch(err => {
							console.error("clipboard read denied", err);
						});
				},

				set_clipboard_text_raw: (textPtr, textLength) => {
					if (!navigator.clipboard) {
						return;
					}

					const text = this.mem.loadString(textPtr, textLength);
					navigator.clipboard.writeText(text)
						.catch(err => {
							console.error("clipboard write denied", err);
						});
				},
			};
		}
	}

	window.odin = window.odin || {};
	window.odin.NaisInterface = NaisInterface;

})();
