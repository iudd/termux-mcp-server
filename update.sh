    # 检查rsync是否可用，如果没有则安装
    if ! check_command "rsync"; then
        log_info "安装rsync工具..."
        if pkg install -y rsync; then
            log_success "rsync安装成功"
        else
            log_error "rsync安装失败，无法进行更新"
            exit 1
        fi
    fi