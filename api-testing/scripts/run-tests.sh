#!/bin/bash

# ================================
# Amoure API 自动化测试脚本
# ================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查Newman是否安装
check_newman() {
    if ! command -v newman &> /dev/null; then
        log_error "Newman CLI 未安装"
        log_info "请运行: npm install -g newman"
        exit 1
    fi
    log_success "Newman CLI 已安装"
}

# 检查服务健康状态
check_health() {
    local env=$1
    local base_url
    
    if [ "$env" = "local" ]; then
        base_url="http://localhost:8080"
    else
        base_url="http://amoure-dev-alb-1565128266.us-east-1.elb.amazonaws.com"
    fi
    
    log_info "检查 $env 环境健康状态..."
    log_info "健康检查URL: $base_url/actuator/health"
    
    # 详细调试信息
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$base_url/actuator/health" 2>&1)
    log_info "HTTP响应码: $http_code"
    
    # 显示完整响应用于调试
    log_info "完整健康检查响应:"
    curl -s "$base_url/actuator/health" || {
        log_error "健康检查请求失败，curl退出码: $?"
        log_info "尝试测试基础连接..."
        curl -I "$base_url" 2>&1
        return 1
    }
    
    if echo "$http_code" | grep -q "200"; then
        log_success "$env 环境健康检查通过"
        return 0
    else
        log_warning "$env 环境健康检查失败 (HTTP: $http_code)，但继续测试"
        return 1
    fi
}

# 运行测试集合
run_collection() {
    local collection=$1
    local environment=$2
    local report_name=$3
    
    log_info "运行测试集合: $collection"
    log_info "使用环境: $environment"
    
    newman run "$collection" \
        -e "$environment" \
        --reporters cli,html \
        --reporter-html-export "reports/$report_name" \
        --timeout-request 10000 \
        --delay-request 1000 \
        --verbose
    
    if [ $? -eq 0 ]; then
        log_success "测试集合运行成功: $report_name"
    else
        log_error "测试集合运行失败: $report_name"
        return 1
    fi
}

# 主函数
main() {
    local env=${1:-"local"}
    local test_type=${2:-"all"}
    
    echo "=========================================="
    echo "🧪 Amoure API 自动化测试"
    echo "=========================================="
    echo ""
    
    # 检查依赖
    check_newman
    
    # 创建报告目录
    mkdir -p reports
    
    # 选择环境文件
    local env_file
    if [ "$env" = "local" ]; then
        env_file="environments/Local-Development.postman_environment.json"
        check_health "local"
    else
        env_file="environments/AWS-Development.postman_environment.json"  
        check_health "aws"
    fi
    
    # 运行测试
    if [ "$test_type" = "v1" ] || [ "$test_type" = "all" ]; then
        log_info "开始V1 API准确测试 (基于真实controller)..."
        run_collection "postman/Amoure-V1-Accurate-Final.postman_collection.json" "$env_file" "v1-${env}-accurate-report.html"
    fi
    
    if [ "$test_type" = "v2" ] || [ "$test_type" = "all" ]; then
        log_info "开始V2 API准确测试 (基于真实controller)..."
        run_collection "postman/Amoure-V2-Accurate-Final.postman_collection.json" "$env_file" "v2-${env}-accurate-report.html"
    fi
    
    echo ""
    echo "=========================================="
    log_success "🎉 测试完成！"
    echo "=========================================="
    echo ""
    
    # 显示报告位置
    echo "📊 测试报告："
    if [ "$test_type" = "v1" ] || [ "$test_type" = "all" ]; then
        echo "  - V1 报告: reports/v1-${env}-accurate-report.html"
    fi
    if [ "$test_type" = "v2" ] || [ "$test_type" = "all" ]; then  
        echo "  - V2 报告: reports/v2-${env}-accurate-report.html"
    fi
    echo ""
}

# 显示使用帮助
show_help() {
    echo "Amoure API 测试脚本"
    echo ""
    echo "Usage: $0 [ENVIRONMENT] [TEST_TYPE]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  local     本地环境测试 (默认)"
    echo "  aws       AWS环境测试"
    echo ""
    echo "TEST_TYPE:"
    echo "  all       运行所有测试 (默认)"
    echo "  v1        只运行V1测试"
    echo "  v2        只运行V2测试"
    echo ""
    echo "Examples:"
    echo "  $0                    # 本地环境运行所有测试"
    echo "  $0 local v1          # 本地环境只运行V1测试"
    echo "  $0 aws v2            # AWS环境只运行V2测试"
    echo ""
}

# 参数处理
case $1 in
    --help|-h)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac