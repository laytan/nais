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

			window.onbeforeunload = () => {
				this.mem.exports._end();
				return null;
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

				set_document_title: (titlePtr, titleLen) => {
					let title = this.mem.loadString(titlePtr, titleLen);
					document.title = title;
				},

				persist_set: (keyPtr, keyLength, valPtr, valLength) => {
					const key = this.mem.loadString(keyPtr, keyLength);
					const val = this.mem.loadString(valPtr, valLength);
					localStorage.setItem(key, val);
				},

				persist_get: (valPtr, valLength, keyPtr, keyLength) => {
					const key = this.mem.loadString(keyPtr, keyLength);
					const val = localStorage.getItem(key);
					if (!val) {
						return -1;
					}

					const len = new TextEncoder().encode(val).length;
					if (valLength == 0) {
						return len
					} else if (len > valLength) {
						throw new Error("buffer overflow");
					} else {
						this.mem.storeString(valPtr, val);
						return len;
					}
				},
			};
		}
	}

	window.odin = window.odin || {};
	window.odin.NaisInterface = NaisInterface;

})();
