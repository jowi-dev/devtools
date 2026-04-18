# Build j command
J_SOURCES = common.ml config.ml nvim.ml project.ml plan.ml til.ml work.ml remote.ml elixir.ml j.ml
j: $(J_SOURCES)
	eval "$$(mise env --shell=bash)" && ocamlopt -I +unix unix.cmxa -o j $(J_SOURCES)

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

	# Install Nix and direnv
	@$(MAKE) nix
	@$(MAKE) direnv

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
	
	# Set DEVTOOLS_ROOT and MACHINE_TYPE in fish config
	@echo "⚙️  Setting environment variables in fish config..."
	@DEVTOOLS_PATH="$$(pwd)"; \
	if ! grep -q "DEVTOOLS_ROOT" ~/.config/fish/config.fish 2>/dev/null; then \
		echo "set -gx DEVTOOLS_ROOT $$DEVTOOLS_PATH" >> ~/.config/fish/config.fish; \
	else \
		sed -i.bak "s|set -gx DEVTOOLS_ROOT .*|set -gx DEVTOOLS_ROOT $$DEVTOOLS_PATH|" ~/.config/fish/config.fish; \
		rm -f ~/.config/fish/config.fish.bak; \
	fi
	@if ! grep -q "MACHINE_TYPE" ~/.config/fish/config.fish 2>/dev/null; then \
		read -p "Is this a work or personal machine? [work/personal] (default: personal): " machine_type; \
		machine_type=$${machine_type:-personal}; \
		echo "set -gx MACHINE_TYPE $$machine_type" >> ~/.config/fish/config.fish; \
		echo "✅ MACHINE_TYPE set to $$machine_type"; \
	else \
		echo "✅ MACHINE_TYPE already configured"; \
	fi

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

# Install Nix via Determinate Systems installer (enables flakes by default)
nix:
	@if ! command -v nix > /dev/null 2>&1; then \
		echo "📦 Installing Nix (Determinate Systems)..."; \
		curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install; \
		echo "✅ Nix installed. Restart your shell to use it."; \
	else \
		echo "✅ Nix already installed"; \
	fi

# Install direnv for automatic Nix shell activation
direnv:
	@if ! command -v direnv > /dev/null 2>&1; then \
		echo "📦 Installing direnv..."; \
		brew install direnv; \
	else \
		echo "✅ direnv already installed"; \
	fi
	@if ! grep -q "direnv hook fish" ~/.config/fish/config.fish 2>/dev/null; then \
		echo 'direnv hook fish | source' >> ~/.config/fish/config.fish; \
		echo "✅ direnv fish hook added"; \
	else \
		echo "✅ direnv fish hook already configured"; \
	fi

clean:
	rm -f j *.cmi *.cmx *.o

.PHONY: install clean nix direnv
