# Build j command
j: j.ml
	PATH="$$(mise env --shell=bash | grep PATH | cut -d= -f2 | tr -d '"'):$$PATH" ocamlopt -I +unix unix.cmxa -o j j.ml

# Install system dependencies and setup development environment
install:
	@echo "🚀 Setting up development environment..."
	@echo ""
	
	# Check if Homebrew is installed, install if not
	@if ! command -v brew > /dev/null 2>&1; then \
		echo "📦 Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
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
	
	@echo ""
	@echo "🎉 Development environment setup complete!"
	@echo "You can now use 'j' from anywhere to sync your configs."

.PHONY: install
