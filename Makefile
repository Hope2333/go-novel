.PHONY: all build build-all compress compress-all clean clean-uncompressed \
        run help info list-platforms

# ============================================
# 项目配置
# ============================================

# 项目名称
PROJECT_NAME := go-novel

# 编译标志
LDFLAGS := -s -w
BUILD_FLAGS := -a -trimpath -ldflags="$(LDFLAGS)"

# 构建目录
BUILD_DIR := build

# UPX压缩级别
UPX_LEVEL := --best

# ============================================
# 平台配置（按优先级和常用程度排序）
# ============================================

# 主要支持平台（已测试通过）
PLATFORMS_MAIN := \
    linux:amd64 linux:arm64 linux:arm linux:386 \
    darwin:amd64 darwin:arm64 \
    windows:amd64 windows:arm64 windows:arm windows:386 \
    freebsd:amd64 freebsd:arm64 freebsd:arm freebsd:386 \
    openbsd:amd64 openbsd:arm64 openbsd:arm openbsd:386 \
    netbsd:amd64 netbsd:arm64 netbsd:arm netbsd:386 \
    illumos:amd64

# 扩展支持平台（可选）
PLATFORMS_EXTENDED := \
    android:amd64 android:arm64 android:arm android:386 \
    aix:ppc64 \
    dragonfly:amd64 \
    solaris:amd64 \
    js:wasm

# RISC-V架构支持（实验性）
PLATFORMS_RISCV := \
    linux:riscv64

# 冷门平台（根据需要启用）
# PLATFORMS_NICHE := \
#     plan9:386 plan9:amd64 plan9:arm
# 合并所有平台
PLATFORMS := $(PLATFORMS_MAIN) $(PLATFORMS_EXTENDED) $(PLATFORMS_RISCV)

# ============================================
# 目标文件定义
# ============================================

# 生成所有平台的输出文件列表
define platform_output
$(BUILD_DIR)/$(PROJECT_NAME)_$(subst :,_, $(1))
endef

ALL_OUTPUTS := $(foreach plat,$(PLATFORMS),$(call platform_output,$(plat)))
ALL_COMPRESSED := $(foreach plat,$(PLATFORMS),$(call platform_output,$(plat)).upx)

# ============================================
# 默认目标
# ============================================

.DEFAULT_GOAL := help

# ============================================
# 构建规则
# ============================================

# 构建所有平台（未压缩）
build-all: $(ALL_OUTPUTS)
	@echo "=========================================="
	@echo "✓ 所有平台构建完成！"
	@echo "=========================================="
	@ls -lh $(BUILD_DIR)/$(PROJECT_NAME)_* | head -20
	@echo "..."
	@echo "总计: $$(ls $(BUILD_DIR)/$(PROJECT_NAME)_* 2>/dev/null | wc -l) 个文件"

# 构建所有平台（压缩版本）
compress-all: $(ALL_COMPRESSED)
	@echo "=========================================="
	@echo "✓ 所有平台压缩完成！"
	@echo "=========================================="
	@echo "压缩文件列表："
	@ls -lh $(BUILD_DIR)/$(PROJECT_NAME)_*.upx | head -20
	@echo "..."
	@echo "总计: $$(ls $(BUILD_DIR)/$(PROJECT_NAME)_*.upx 2>/dev/null | wc -l) 个压缩文件"

# 构建指定平台
build-%:
	@$(MAKE) build PLATFORM=$(*)

# 通用构建规则
$(BUILD_DIR)/$(PROJECT_NAME)_%:	@mkdir -p $(BUILD_DIR)
	@plat=$(subst _,:,$(subst $(PROJECT_NAME)_,,$(notdir $@))); \
	GOOS=$${plat%%:*}; \
	GOARCH=$${plat##*:}; \
	echo "🔨 构建 $$GOOS/$$GOARCH ..."; \
	CGO_ENABLED=0 GOOS=$$GOOS GOARCH=$$GOARCH go build $(BUILD_FLAGS) -o $@ . 2>&1 | grep -v "^#" || true; \
	if [ -f "$@" ]; then \
		size=$$(ls -lh $@ | awk '{print $$5}'); \
		echo "  ✓ 编译成功: $@ ($$size)"; \
	else \
		echo "  ✗ 编译失败: $$GOOS/$$GOARCH"; \
		exit 1; \
	fi

# 压缩指定平台
compress-%:
	@$(MAKE) compress PLATFORM=$(*)

# 通用压缩规则
$(BUILD_DIR)/$(PROJECT_NAME)_%_upx: $(BUILD_DIR)/$(PROJECT_NAME)_%
	@plat=$(subst _,:,$(subst $(PROJECT_NAME)_,,$(subst .upx,,$(notdir $@)))); \
	GOOS=$${plat%%:*}; \
	GOARCH=$${plat##*:}; \
	echo "📦 压缩 $$GOOS/$$GOARCH ..."; \
	if command -v upx &> /dev/null; then \
		upx $(UPX_LEVEL) $< -o $@; \
		if [ $$? -eq 0 ]; then \
			ORIGINAL_SIZE=$$(stat -c%s $< 2>/dev/null || stat -f%z $< 2>/dev/null); \
			COMPRESSED_SIZE=$$(stat -c%s $@ 2>/dev/null || stat -f%z $@ 2>/dev/null); \
			SAVED=$$((ORIGINAL_SIZE - COMPRESSED_SIZE)); \
			PERCENT=$$((SAVED * 100 / ORIGINAL_SIZE)); \
			echo "  ✓ 压缩成功！"; \
			echo "    原始: $$(printf '%.2f' $$(echo "$$ORIGINAL_SIZE/1024/1024" | bc -l)) MB"; \
			echo "    压缩: $$(printf '%.2f' $$(echo "$$COMPRESSED_SIZE/1024/1024" | bc -l)) MB"; \
			echo "    节省: $$(printf '%.2f' $$(echo "$$SAVED/1024/1024" | bc -l)) MB ($$PERCENT%)"; \
		else \
			echo "  ✗ UPX压缩失败"; \
			exit 1; \
		fi \
	else \
		echo "  ⚠️ 警告: UPX未安装，无法压缩"; \
		exit 1; \
	fi

# ============================================
# 清理规则
# ============================================

# 清理所有构建文件
clean:	@echo "🧹 清理所有构建文件..."
	@rm -rf $(BUILD_DIR)
	@echo "✓ 清理完成！"

# 仅清理未压缩文件，保留压缩版本
clean-uncompressed:
	@echo "🧹 清理未压缩文件..."
	@count=0; \
	for file in $(BUILD_DIR)/$(PROJECT_NAME)_*; do \
		if [ -f "$$file" ] && [ ! -f "$$file.upx" ]; then \
			rm -f "$$file"; \
			count=$$((count + 1)); \
		fi \
	done; \
	echo "✓ 已清理 $$count 个未压缩文件"

# 清理特定平台
clean-%:
	@plat=$(*); \
	echo "🧹 清理平台: $$plat"; \
	rm -f $(BUILD_DIR)/$(PROJECT_NAME)_$${plat} $(BUILD_DIR)/$(PROJECT_NAME)_$${plat}.upx; \
	echo "✓ 清理完成"

# ============================================
# 实用命令
# ============================================

# 重新构建所有
rebuild: clean build-all

# 重新构建并压缩所有
rebuild-compress: clean compress-all

# 运行当前平台版本
run:
	@echo "🚀 运行当前平台版本..."
	@GOOS=$$(go env GOOS) GOARCH=$$(go env GOARCH) ./$(BUILD_DIR)/$(PROJECT_NAME)_$$(go env GOOS)_$$(go env GOARCH) || \
	(echo "⚠️ 未找到当前平台的二进制文件，正在构建..."; \
	$(MAKE) build-$$(go env GOOS)_$$(go env GOARCH); \
	./$(BUILD_DIR)/$(PROJECT_NAME)_$$(go env GOOS)_$$(go env GOARCH))

# ============================================
# 信息显示
# ============================================

# 显示帮助信息
help:
	@echo "=========================================="
	@echo "  $(PROJECT_NAME) 全平台构建系统"
	@echo "=========================================="	@echo ""
	@echo "📋 可用的make目标："
	@echo ""
	@echo "  make build-all          - 构建所有支持的平台（未压缩）"
	@echo "  make compress-all       - 构建并压缩所有支持的平台"
	@echo "  make build-<platform>   - 构建指定平台（未压缩）"
	@echo "  make compress-<platform>- 构建并压缩指定平台"
	@echo "  make clean              - 清理所有构建文件"
	@echo "  make clean-uncompressed - 仅清理未压缩文件"
	@echo "  make clean-<platform>   - 清理指定平台"
	@echo "  make rebuild            - 清理并重新构建所有平台"
	@echo "  make rebuild-compress   - 清理并重新构建压缩所有平台"
	@echo "  make run                - 运行当前平台版本"
	@echo "  make list-platforms     - 列出所有支持的平台"
	@echo "  make info               - 显示构建统计信息"
	@echo "  make help               - 显示此帮助信息"
	@echo ""
	@echo "📦 平台命名格式："
	@echo "  <GOOS>_<GOARCH>"
	@echo ""
	@echo "📝 使用示例："
	@echo "  # 构建Linux amd64版本"
	@echo "  make build-linux_amd64"
	@echo ""
	@echo "  # 构建并压缩Windows amd64版本"
	@echo "  make compress-windows_amd64"
	@echo ""
	@echo "  # 构建所有平台"
	@echo "  make build-all"
	@echo ""
	@echo "  # 构建并压缩所有平台"
	@echo "  make compress-all"
	@echo ""
	@echo "  # 清理特定平台"
	@echo "  make clean-linux_amd64"
	@echo ""
	@echo "  # 查看所有支持的平台"
	@echo "  make list-platforms"
	@echo ""
	@echo "=========================================="

# 列出所有支持的平台
list-platforms:
	@echo "=========================================="
	@echo "  支持的平台列表"
	@echo "=========================================="
	@echo ""
	@echo "【主要平台（已测试）】"
	@for plat in $(PLATFORMS_MAIN); do \
		GOOS=$${plat%%:*}; \		GOARCH=$${plat##*:}; \
		printf "  %-12s %-8s\n" "$$GOOS" "$$GOARCH"; \
	done | column -t
	@echo ""
	@echo "【扩展平台（可选）】"
	@for plat in $(PLATFORMS_EXTENDED); do \
		GOOS=$${plat%%:*}; \
		GOARCH=$${plat##*:}; \
		printf "  %-12s %-8s\n" "$$GOOS" "$$GOARCH"; \
	done | column -t
	@echo ""
	@echo "【RISC-V架构（实验性）】"
	@for plat in $(PLATFORMS_RISCV); do \
		GOOS=$${plat%%:*}; \
		GOARCH=$${plat##*:}; \
		printf "  %-12s %-8s\n" "$$GOOS" "$$GOARCH"; \
	done | column -t
	@echo ""
	@echo "总计: $$(echo $(PLATFORMS) | wc -w) 个平台组合"
	@echo ""

# 显示构建统计信息
info:
	@echo "=========================================="
	@echo "  构建统计信息"
	@echo "=========================================="
	@echo ""
	@echo "项目名称: $(PROJECT_NAME)"
	@echo "构建目录: $(BUILD_DIR)"
	@echo "UPX级别: $(UPX_LEVEL)"
	@echo ""
	@echo "平台统计："
	@echo "  主要平台: $$(echo $(PLATFORMS_MAIN) | wc -w) 个"
	@echo "  扩展平台: $$(echo $(PLATFORMS_EXTENDED) | wc -w) 个"
	@echo "  RISC-V平台: $$(echo $(PLATFORMS_RISCV) | wc -w) 个"
	@echo "  总计: $$(echo $(PLATFORMS) | wc -w) 个平台组合"
	@echo ""
	@if [ -d "$(BUILD_DIR)" ]; then \
		echo "当前构建文件："; \
		echo "  未压缩: $$(ls $(BUILD_DIR)/$(PROJECT_NAME)_* 2>/dev/null | grep -v "\.upx$$" | wc -l) 个"; \
		echo "  压缩版: $$(ls $(BUILD_DIR)/$(PROJECT_NAME)_*.upx 2>/dev/null | wc -l) 个"; \
		echo "  总计: $$(ls $(BUILD_DIR)/$(PROJECT_NAME)_* 2>/dev/null | wc -l) 个"; \
		echo ""; \
		echo "磁盘占用："; \
		du -sh $(BUILD_DIR) 2>/dev/null | awk '{print "  " $$1}'; \
	fi
	@echo ""

# ============================================
# 快速构建命令（常用平台）# ============================================

# 构建主流桌面平台
build-desktop: \
    build-linux_amd64 \
    build-darwin_amd64 \
    build-darwin_arm64 \
    build-windows_amd64
	@echo "✓ 桌面平台构建完成！"

# 构建主流服务器平台
build-server: \
    build-linux_amd64 \
    build-linux_arm64 \
    build-freebsd_amd64
	@echo "✓ 服务器平台构建完成！"

# 构建移动平台
build-mobile: \
    build-android_amd64 \
    build-android_arm64 \
    build-android_arm
	@echo "✓ 移动平台构建完成！"

# 压缩主流桌面平台
compress-desktop: \
    compress-linux_amd64 \
    compress-darwin_amd64 \
    compress-darwin_arm64 \
    compress-windows_amd64
	@echo "✓ 桌面平台压缩完成！"

# 压缩主流服务器平台
compress-server: \
    compress-linux_amd64 \
    compress-linux_arm64 \
    compress-freebsd_amd64
	@echo "✓ 服务器平台压缩完成！"

# 压缩移动平台
compress-mobile: \
    compress-android_amd64 \
    compress-android_arm64 \
    compress-android_arm
	@echo "✓ 移动平台压缩完成！"
