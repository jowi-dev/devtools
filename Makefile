# Build j command
j: j.ml
	eval "$$(mise env --shell=bash)" && ocamlopt -I +unix unix.cmxa -o j j.ml

# Install system dependencies and setup development environment
install:
	@echo "🚀 Setting up development environment..."
	@echo ""
	
	# Check if Homebrew is installed, install if not
	@if ! command -v brew > /dev/null 2>&1; then \
		echo "📦 Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
		echo "📦 Adding Homebrew to PATH..."; \
		echo >> ~/.zprofile; \
		echo 'eval "$$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile; \
		echo >> ~/.config/fish/config.fish; \
		echo 'eval "$$(/opt/homebrew/bin/brew shellenv)"' >> ~/.config/fish/config.fish; \
		eval "$$(/opt/homebrew/bin/brew shellenv)"; \
	else \
		echo "✅ Homebrew already installed"; \
	fi

	# Install tools from Brewfile
	@echo "📦 Installing tools from Brewfile..."
	@brew bundle
	
	# Check if mise is available, install if not
	@if ! command -v mise > /dev/null 2>&1; then \
		echo "📦 Installing mise..."; \
		brew install mise; \
	else \
		echo "✅ mise already installed"; \
	fi
	
	# Install mise tools
	@echo "📦 Installing mise tools..."
	@mise install
	
	# Build j command
	@echo "🔨 Building j command..."
	@$(MAKE) j
	
	# Install j command globally
	@echo "📦 Installing j command globally..."
	@./j install
	
	# Export all configs to system
	@echo "⚙️  Exporting all configs to system locations..."
	@j export --all

	# Set Fish as default shell
	@echo "🐟 Setting Fish as default shell..."
	@if ! grep -q "$$(which fish)" /etc/shells 2>/dev/null; then \
		echo "$$(which fish)" | sudo tee -a /etc/shells; \
	fi
	@if [ "$$SHELL" != "$$(which fish)" ]; then \
		chsh -s $$(which fish); \
		echo "✅ Fish set as default shell (restart terminal to take effect)"; \
	else \
		echo "✅ Fish already default shell"; \
	fi

	@echo ""
	@echo "🎉 Development environment setup complete!"
	@echo "You can now use 'j' from anywhere to sync your configs."

.PHONY: install
