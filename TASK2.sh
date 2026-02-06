#!/bin/bash

# === ПЕРЕМЕННЫЕ ДЛЯ ЗАДАЧИ 6 ===
declare -a ALTERNATIVES CRITERIA
declare -A CRITERIA_TYPES CRITERIA_WEIGHTS
declare -A DECISION_MATRIX NORMALIZED_MATRIX
declare -A PRINCIPLE_RESULTS PRINCIPLE_RANKS
declare -A WEIGHTS_SCORES
declare THRESHOLD MAIN_CRITERION CONCESSION_WEIGHT
declare IDEAL_POINT ANTI_IDEAL_POINT
declare PROGRESS_FILE PROGRESS_PID bcsc=6

DEFAULT_TEMPLATE=$(cat <<'EOF'
# ШАБЛОН ДЛЯ ЗАДАЧИ 6: Выбор при определенности

[Альтернативы]
UBUNTU, FEDORA, ASTRA_LINUX, ALT_LINUX, CALCULATE_LINUX

[Критерии]
БЕЗОПАСНОСТЬ, СТАБИЛЬНОСТЬ, ДОКУМЕНТАЦИЯ, ПОДДЕРЖКА, СТОИМОСТЬ

[Типы критериев]
# Все качественные критерии максимизируются, стоимость минимизируется
БЕЗОПАСНОСТЬ:max
СТАБИЛЬНОСТЬ:max
ДОКУМЕНТАЦИЯ:max
ПОДДЕРЖКА:max
СТОИМОСТЬ:min

[Веса критериев]
# Веса полностью согласованы с задачей 4 (нормированы к 1.0)
СТОИМОСТЬ:0.15
СТАБИЛЬНОСТЬ:0.25
БЕЗОПАСНОСТЬ:0.35
ДОКУМЕНТАЦИЯ:0.15
ПОДДЕРЖКА:0.10

[Матрица решений]
# Формат строки: АЛЬТЕРНАТИВА:БЕЗОПАСНОСТЬ,СТАБИЛЬНОСТЬ,
#          ДОКУМЕНТАЦИЯ,ПОДДЕРЖКА,СТОИМОСТЬ
UBUNTU:80,80,90,90,50
FEDORA:70,40,60,60,50
ASTRA_LINUX:80,80,70,80,400
ALT_LINUX:90,80,70,70,100
CALCULATE_LINUX:70,80,60,60,150

[Параметры]
ПОРОГ_НОРМАЛИЗОВАННЫЙ=70
ПОРОГ_ИСХОДНЫЙ=80
ГЛАВНЫЙ_КРИТЕРИЙ=БЕЗОПАСНОСТЬ
ВЕЛИЧИНА_УСТУПКИ=0.10
EOF
)

# === ИНТЕРФЕЙС ===
zenity_show_conditions() {
    if ! data_validate; then
        zenity --error --title="Ошибка данных" \
            --text="Данные не загружены или повреждены.\nЗагрузите данные заново." --width=500 2>/dev/null
        return
    fi

    local conditions_text="ЗАДАЧА 6: МНОГОКРИТЕРИАЛЬНЫЙ ВЫБОР В УСЛОВИЯХ ОПРЕДЕЛЕННОСТИ

ЦЕЛЬ:
Выбрать оптимальную альтернативу при точно известных значениях всех критериев.

ПОДЗАДАЧИ:
1. Нормализация критериев
   - Приведение всех критериев к максимизации
   - Линейное масштабирование

2. Применение методов выбора (8 принципов):
   1. Аддитивная свертка
   2. Парето-оптимальность
   3. Метод идеальной точки
   4. Метод главного критерия
   5. Метод уступок
   6. Метод конъюнкции
   7. Лексикографический метод
   8. Принцип максимакса

3. Сравнительный анализ методов
   - Частотный анализ предпочтений
   - Итоговая рекомендация

ДАННЫЕ:
• Альтернатив: ${#ALTERNATIVES[@]}
• Критериев: ${#CRITERIA[@]}
• Главный критерий: $MAIN_CRITERION
• Величина уступки: $CONCESSION_WEIGHT"

    echo "$conditions_text" | zenity --text-info --title="Задача 6" \
        --width=750 --height=650 --font="monospace 10" 2>/dev/null || true
}

zenity_main_menu() {
    bc_init

    # Загрузка данных по умолчанию
    if ! data_load_default; then
        zenity --error \
            --title="Критическая ошибка" \
            --text="Не удалось загрузить данные по умолчанию.\nПрограмма не может быть запущена." \
            --width=400 2>/dev/null
        return 1
    fi

    while true; do
        local choice=$(zenity --list \
            --title="Задача 6: Выбор при определенности" \
            --text="Действие:" \
            --column="Опция" \
            "▶ Выполнить все вычисления" \
            "1. Предварительная обработка" \
            "2. Принципы оптимальности" \
            "3. Итоговый анализ" \
            "✏️ Редактировать данные" \
            "📋 Условия задачи" \
            --width=350 --height=450 2>/dev/null)

        if [ -z "$choice" ]; then
            break
        fi

        case "$choice" in
            "▶ Выполнить все вычисления")
                zenity_run_all_tasks
                ;;
            "1. Предварительная обработка")
                { subtask1_preprocessing; } | zenity --text-info \
                    --title="Задача 1: Предобработка" \
                    --width=650 --height=550 --font="monospace 10" 2>/dev/null || subtask1_preprocessing
                ;;
            "2. Принципы оптимальности")
                { subtask2_optimality_principles; } | zenity --text-info \
                    --title="Задача 2: Принципы оптимальности" \
                    --width=600 --height=700 --font="monospace 10" 2>/dev/null || subtask2_optimality_principles
                ;;
            "3. Итоговый анализ")
                { subtask3_final_analysis; } | zenity --text-info \
                    --title="Задача 3: Итоговый анализ" \
                    --width=450 --height=400 --font="monospace 10" 2>/dev/null || subtask3_final_analysis
                ;;
            "✏️ Редактировать данные")
                data_edit
                ;;
            "📋 Условия задачи")
                zenity_show_conditions
                ;;
        esac
    done

    zenity_progress_stop
    bc_cleanup
}

zenity_run_all_tasks() {
    if ! data_validate; then
        zenity --error \
            --title="Ошибка данных" \
            --text="Данные не загружены или повреждены.\nЗагрузите данные заново." \
            --width=500 2>/dev/null
        return
    fi

    local temp_file=$(mktemp)

    zenity_progress_start "Решение задачи 6" "Подготовка данных..."

    {
        echo "=== РЕШЕНИЕ ЗАДАЧИ 6 ==="
        echo ""

        echo "10" >&3
        echo "# 1. Предварительная обработка данных..." >&3
        subtask1_preprocessing

        echo "40" >&3
        echo "# 2. Применение принципов оптимальности..." >&3
        subtask2_optimality_principles

        echo "70" >&3
        echo "# 3. Итоговый анализ..." >&3
        subtask3_final_analysis

        echo "90" >&3
        echo "# Формирование выводов..." >&3
        echo ""
        echo "=== ВЫВОДЫ И РЕКОМЕНДАЦИИ ==="
        echo ""
        __generate_conclusions

        echo "100" >&3
        echo "# Вычисления завершены" >&3
        sleep 0.5

    } > "$temp_file" 2>&1

    zenity_progress_stop

    cat "$temp_file" | zenity --text-info \
        --title="Решение задачи 6" \
        --width=650 --height=950 \
        --font="monospace 11" 2>/dev/null || cat "$temp_file"

    rm -f "$temp_file"
}

zenity_progress_start() {
    local title="$1"
    local initial_text="${2:-"Инициализация..."}"

    PROGRESS_FILE=$(mktemp -u)
    mkfifo "$PROGRESS_FILE" 2>/dev/null

    zenity --progress \
        --title="$title" \
        --text="$initial_text" \
        --percentage=0 \
        --auto-close \
        --auto-kill \
        --width=500 \
        < "$PROGRESS_FILE" &

    PROGRESS_PID=$!
    exec 3>"$PROGRESS_FILE" 2>/dev/null
}

zenity_progress_stop() {
    if [[ -n "$PROGRESS_PID" ]]; then
        exec 3>&- 2>/dev/null
        [[ -f "$PROGRESS_FILE" ]] && rm -f "$PROGRESS_FILE"
        wait "$PROGRESS_PID" 2>/dev/null || true
        PROGRESS_PID=""
        PROGRESS_FILE=""
    fi
}

# === ПОДЗАДАЧИ ===
subtask1_preprocessing() {
    echo "=== ЗАДАЧА 1: ПРЕДВАРИТЕЛЬНАЯ ОБРАБОТКА ==="
    echo ""

    # 1.1 Критерии
    echo "1.1 Критерии и веса:"
    for crit in "${CRITERIA[@]}"; do
        LC_NUMERIC=C printf "  %-15s %s  вес %.4f\n" \
            "$crit" "${CRITERIA_TYPES[$crit]}" "${CRITERIA_WEIGHTS[$crit]:-0}"
    done
    echo ""

    # 1.2 Исходная матрица
    echo "1.2 Исходная матрица решений:"
    LC_NUMERIC=C printf "%-15s" ""
    for crit in "${CRITERIA[@]}"; do LC_NUMERIC=C printf " %10s" "$crit"; done
    echo ""
    for alt in "${ALTERNATIVES[@]}"; do
        LC_NUMERIC=C printf "%-15s" "$alt"
        for crit in "${CRITERIA[@]}"; do
            LC_NUMERIC=C printf " %10.2f" "${DECISION_MATRIX[$alt,$crit]:-0}"
        done
        echo ""
    done
    echo ""

    # 1.3 Нормализация: min/max → [0,1], все критерии → max
    declare -A min_values max_values
    for crit in "${CRITERIA[@]}"; do
        local min_val=999999999 max_val=-999999999
        for alt in "${ALTERNATIVES[@]}"; do
            local val="${DECISION_MATRIX[$alt,$crit]:-0}"
            if bc_compare "$val" "$min_val" "lt"; then min_val="$val"; fi
            if bc_compare "$val" "$max_val" "gt"; then max_val="$val"; fi
        done
        min_values["$crit"]="$min_val"
        max_values["$crit"]="$max_val"
    done

    for alt in "${ALTERNATIVES[@]}"; do
        for crit in "${CRITERIA[@]}"; do
            local val="${DECISION_MATRIX[$alt,$crit]:-0}"
            local type="${CRITERIA_TYPES[$crit]}"
            local min_val="${min_values[$crit]}"
            local max_val="${max_values[$crit]}"
            local range
            range=$(bc_calc "$max_val - $min_val")

            if [ "$type" = "min" ]; then
                if bc_compare "$range" "0" "gt"; then
                    NORMALIZED_MATRIX["$alt,$crit"]=$(bc_calc "($max_val - $val) / $range")
                else
                    NORMALIZED_MATRIX["$alt,$crit"]=1
                fi
            else
                if bc_compare "$range" "0" "gt"; then
                    NORMALIZED_MATRIX["$alt,$crit"]=$(bc_calc "($val - $min_val) / $range")
                else
                    NORMALIZED_MATRIX["$alt,$crit"]=1
                fi
            fi
        done
    done

    # 1.4 Нормализованная матрица
    echo "1.3 Нормализованная матрица (все критерии → max, [0,1]):"
    LC_NUMERIC=C printf "%-15s" ""
    for crit in "${CRITERIA[@]}"; do LC_NUMERIC=C printf " %10s" "$crit"; done
    echo ""
    for alt in "${ALTERNATIVES[@]}"; do
        LC_NUMERIC=C printf "%-15s" "$alt"
        for crit in "${CRITERIA[@]}"; do
            LC_NUMERIC=C printf " %10.4f" "${NORMALIZED_MATRIX[$alt,$crit]:-0}"
        done
        echo ""
    done
    echo ""
}

subtask2_optimality_principles() {
    echo "=== ЗАДАЧА 2: ПРИНЦИПЫ ОПТИМАЛЬНОСТИ ==="
    echo ""

    # Локальный помощник: печать списка или "(нет)"
    __print_list_or_none() {
        local label="$1"; shift
        if [ "$#" -gt 0 ]; then
            echo "  $label: $*"
        else
            echo "  $label: (нет)"
        fi
    }

    # 2.1 Максимакс
    echo "2.1 Максимакс — max_j x_ij:"
    local -a maximax_best_alts=()
    local maximax_best_value=-999999

    for alt in "${ALTERNATIVES[@]}"; do
        local max_val=-999999
        for crit in "${CRITERIA[@]}"; do
            local val="${NORMALIZED_MATRIX[$alt,$crit]:-0}"
            if bc_compare "$val" "$max_val" "gt"; then max_val="$val"; fi
        done

        PRINCIPLE_RESULTS["МАКСИМАКС,$alt"]="$max_val"
        LC_NUMERIC=C printf "  %-15s %.4f" "$alt" "$max_val"

        if bc_compare "$max_val" "$maximax_best_value" "gt"; then
            maximax_best_value="$max_val"
            maximax_best_alts=("$alt")
            echo "  ✓"
        elif bc_compare "$max_val" "$maximax_best_value" "eq"; then
            maximax_best_alts+=("$alt")
            echo "  ✓"
        else
            echo ""
        fi
    done
    LC_NUMERIC=C printf "→ %s (%.4f)\n\n" "${maximax_best_alts[*]}" "$maximax_best_value"

    # 2.2 Аддитивная свёртка
    echo "2.2 Аддитивная свёртка — Σ w_j·x_ij:"
    local -a additive_best_alts=()
    local additive_best_value=-999999

    for alt in "${ALTERNATIVES[@]}"; do
        local weighted_sum=0
        for crit in "${CRITERIA[@]}"; do
            local val="${NORMALIZED_MATRIX[$alt,$crit]:-0}"
            local weight="${CRITERIA_WEIGHTS[$crit]:-0}"
            weighted_sum=$(bc_calc "$weighted_sum + $val * $weight")
        done

        PRINCIPLE_RESULTS["АДДИТИВНАЯ_СВЕРТКА,$alt"]="$weighted_sum"
        LC_NUMERIC=C printf "  %-15s %.4f" "$alt" "$weighted_sum"

        if bc_compare "$weighted_sum" "$additive_best_value" "gt"; then
            additive_best_value="$weighted_sum"
            additive_best_alts=("$alt")
            echo "  ✓"
        elif bc_compare "$weighted_sum" "$additive_best_value" "eq"; then
            additive_best_alts+=("$alt")
            echo "  ✓"
        else
            echo ""
        fi
    done
    LC_NUMERIC=C printf "→ %s (%.4f)\n\n" "${additive_best_alts[*]}" "$additive_best_value"

    # 2.3 Парето
    echo "2.3 Парето-оптимальность:"
    local -a pareto_optimal=()
    local -a dominated=()

    for alt_i in "${ALTERNATIVES[@]}"; do
        local dominated_i=0

        for alt_j in "${ALTERNATIVES[@]}"; do
            [ "$alt_i" = "$alt_j" ] && continue

            local all_better_or_equal=1
            local strictly_better=0

            for crit in "${CRITERIA[@]}"; do
                local val_i="${NORMALIZED_MATRIX[$alt_i,$crit]:-0}"
                local val_j="${NORMALIZED_MATRIX[$alt_j,$crit]:-0}"

                if bc_compare "$val_j" "$val_i" "lt"; then
                    all_better_or_equal=0
                    break
                elif bc_compare "$val_j" "$val_i" "gt"; then
                    strictly_better=1
                fi
            done

            if [ "$all_better_or_equal" -eq 1 ] && [ "$strictly_better" -eq 1 ]; then
                dominated_i=1
                break
            fi
        done

        if [ "$dominated_i" -eq 0 ]; then
            pareto_optimal+=("$alt_i")
            PRINCIPLE_RESULTS["ПАРЕТО,$alt_i"]=1
        else
            dominated+=("$alt_i")
            PRINCIPLE_RESULTS["ПАРЕТО,$alt_i"]=0
        fi
    done

    __print_list_or_none "Недоминируемые" "${pareto_optimal[@]}"
    if [ "${#dominated[@]}" -gt 0 ]; then
        __print_list_or_none "Доминируемые" "${dominated[@]}"
    fi
    echo ""

    # 2.4 TOPSIS
    echo "2.4 Идеальная точка (TOPSIS) — C = d_- / (d_+ + d_-):"
    declare -A ideal_point anti_ideal_point
    for crit in "${CRITERIA[@]}"; do
        ideal_point["$crit"]=1
        anti_ideal_point["$crit"]=0
    done

    local -a ideal_point_best_alts=()
    local ideal_point_best_value=-999999

    for alt in "${ALTERNATIVES[@]}"; do
        local dist_to_ideal=0 dist_to_anti=0

        for crit in "${CRITERIA[@]}"; do
            local val="${NORMALIZED_MATRIX[$alt,$crit]:-0}"
            local weight="${CRITERIA_WEIGHTS[$crit]:-0}"

            local diff_ideal diff_anti
            diff_ideal=$(bc_calc "${ideal_point[$crit]} - $val")
            dist_to_ideal=$(bc_calc "$dist_to_ideal + ($diff_ideal * $diff_ideal) * $weight")

            diff_anti=$(bc_calc "$val - ${anti_ideal_point[$crit]}")
            dist_to_anti=$(bc_calc "$dist_to_anti + ($diff_anti * $diff_anti) * $weight")
        done

        dist_to_ideal=$(bc_calc "sqrt($dist_to_ideal)")
        dist_to_anti=$(bc_calc "sqrt($dist_to_anti)")

        local closeness
        closeness=$(bc_calc "$dist_to_anti / ($dist_to_ideal + $dist_to_anti)")

        PRINCIPLE_RESULTS["ИДЕАЛЬНАЯ_ТОЧКА,$alt"]="$closeness"
        LC_NUMERIC=C printf "  %-15s %.4f" "$alt" "$closeness"

        if bc_compare "$closeness" "$ideal_point_best_value" "gt"; then
            ideal_point_best_value="$closeness"
            ideal_point_best_alts=("$alt")
            echo "  ✓"
        elif bc_compare "$closeness" "$ideal_point_best_value" "eq"; then
            ideal_point_best_alts+=("$alt")
            echo "  ✓"
        else
            echo ""
        fi
    done
    LC_NUMERIC=C printf "→ %s (%.4f)\n\n" "${ideal_point_best_alts[*]}" "$ideal_point_best_value"

    # 2.5 Главный критерий
    echo "2.5 Главный критерий ($MAIN_CRITERION):"
    if ! __exists_in_array CRITERIA "$MAIN_CRITERION"; then
        MAIN_CRITERION="${CRITERIA[0]}"
    fi

    local -a main_criterion_best_alts=()
    local main_criterion_best_value=-999999

    for alt in "${ALTERNATIVES[@]}"; do
        local feasible=1

        for crit in "${CRITERIA[@]}"; do
            [ "$crit" = "$MAIN_CRITERION" ] && continue

            local orig_val="${DECISION_MATRIX[$alt,$crit]:-0}"
            local type="${CRITERIA_TYPES[$crit]}"

            if [ "$type" = "min" ]; then
                if bc_compare "$orig_val" "$THRESHOLD_ORIG" "gt"; then feasible=0; break; fi
            else
                if bc_compare "$orig_val" "$THRESHOLD_NORM" "lt"; then feasible=0; break; fi
            fi
        done

        if [ "$feasible" -eq 1 ]; then
            local main_val="${NORMALIZED_MATRIX[$alt,$MAIN_CRITERION]:-0}"
            PRINCIPLE_RESULTS["ГЛАВНЫЙ_КРИТЕРИЙ,$alt"]="$main_val"
            LC_NUMERIC=C printf "  %-15s %.4f  ✓\n" "$alt" "$main_val"

            if bc_compare "$main_val" "$main_criterion_best_value" "gt"; then
                main_criterion_best_value="$main_val"
                main_criterion_best_alts=("$alt")
            elif bc_compare "$main_val" "$main_criterion_best_value" "eq"; then
                main_criterion_best_alts+=("$alt")
            fi
        else
            PRINCIPLE_RESULTS["ГЛАВНЫЙ_КРИТЕРИЙ,$alt"]=0
            LC_NUMERIC=C printf "  %-15s —\n" "$alt"
        fi
    done

    if [ ${#main_criterion_best_alts[@]} -gt 0 ]; then
        LC_NUMERIC=C printf "→ %s (%.4f)\n\n" "${main_criterion_best_alts[*]}" "$main_criterion_best_value"
    else
        echo "→ нет допустимых альтернатив"
        echo ""
    fi

    # 2.6 Уступки
    echo "2.6 Уступки (δ = $CONCESSION_WEIGHT):"
    local -a sorted_criteria_weights=()
    for crit in "${CRITERIA[@]}"; do
        sorted_criteria_weights+=("$crit:${CRITERIA_WEIGHTS[$crit]:-0}")
    done
    IFS=$'\n' sorted_criteria_weights=($(LC_NUMERIC=C printf "%s\n" "${sorted_criteria_weights[@]}" | sort -t: -k2 -nr))
    unset IFS

    local -a remaining_alts=("${ALTERNATIVES[@]}")

    for crit_data in "${sorted_criteria_weights[@]}"; do
        [ ${#remaining_alts[@]} -le 1 ] && break

        local crit="${crit_data%:*}"
        local max_val=-999999
        for alt in "${remaining_alts[@]}"; do
            local val="${NORMALIZED_MATRIX[$alt,$crit]:-0}"
            if bc_compare "$val" "$max_val" "gt"; then max_val="$val"; fi
        done

        local concession
        concession=$(bc_calc "$max_val * (1 - $CONCESSION_WEIGHT)")

        local -a new_remaining=()
        for alt in "${remaining_alts[@]}"; do
            local val="${NORMALIZED_MATRIX[$alt,$crit]:-0}"
            if bc_compare "$val" "$concession" "ge"; then
                new_remaining+=("$alt")
            fi
        done
        remaining_alts=("${new_remaining[@]}")
    done

    for alt in "${ALTERNATIVES[@]}"; do
        local selected=0
        for selected_alt in "${remaining_alts[@]}"; do
            if [ "$alt" = "$selected_alt" ]; then selected=1; break; fi
        done
        PRINCIPLE_RESULTS["УСТУПКИ,$alt"]=$selected
    done

    __print_list_or_none "Остаются" "${remaining_alts[@]}"
    echo ""

    # 2.7 Конъюнкция
    echo "2.7 Конъюнкция (все пороги одновременно):"
    local -a conjunction_best_alts=()

    for alt in "${ALTERNATIVES[@]}"; do
        local passes_all=1

        for crit in "${CRITERIA[@]}"; do
            local orig_val="${DECISION_MATRIX[$alt,$crit]:-0}"
            local type="${CRITERIA_TYPES[$crit]}"

            if [ "$type" = "min" ]; then
                if bc_compare "$orig_val" "$THRESHOLD_ORIG" "gt"; then passes_all=0; break; fi
            else
                if bc_compare "$orig_val" "$THRESHOLD_NORM" "lt"; then passes_all=0; break; fi
            fi
        done

        PRINCIPLE_RESULTS["КОНЪЮНКЦИЯ,$alt"]="$passes_all"
        if [ "$passes_all" -eq 1 ]; then
            conjunction_best_alts+=("$alt")
        fi
    done

    __print_list_or_none "Проходят" "${conjunction_best_alts[@]}"
    echo ""

    # 2.8 Лексикографический
    echo "2.8 Лексикографический (по весам критериев):"
    local -a sorted_criteria=()
    for crit in "${CRITERIA[@]}"; do
        sorted_criteria+=("$crit:${CRITERIA_WEIGHTS[$crit]:-0}")
    done
    IFS=$'\n' sorted_criteria=($(LC_NUMERIC=C printf "%s\n" "${sorted_criteria[@]}" | sort -t: -k2 -nr))
    unset IFS

    local -a current_alts=("${ALTERNATIVES[@]}")

    for crit_data in "${sorted_criteria[@]}"; do
        [ ${#current_alts[@]} -le 1 ] && break

        local crit="${crit_data%:*}"
        local max_val=-999999
        for alt in "${current_alts[@]}"; do
            local val="${NORMALIZED_MATRIX[$alt,$crit]:-0}"
            if bc_compare "$val" "$max_val" "gt"; then max_val="$val"; fi
        done

        local -a new_current=()
        for alt in "${current_alts[@]}"; do
            local val="${NORMALIZED_MATRIX[$alt,$crit]:-0}"
            if bc_compare "$val" "$max_val" "eq"; then
                new_current+=("$alt")
            fi
        done
        current_alts=("${new_current[@]}")
    done

    for alt in "${ALTERNATIVES[@]}"; do
        local selected=0
        for selected_alt in "${current_alts[@]}"; do
            if [ "$alt" = "$selected_alt" ]; then selected=1; break; fi
        done
        PRINCIPLE_RESULTS["ЛЕКСИКОГРАФИЧЕСКИЙ,$alt"]=$selected
    done

    __print_list_or_none "Остаются" "${current_alts[@]}"
    echo ""
}

subtask3_final_analysis() {
    echo "=== ЗАДАЧА 3: ИТОГОВЫЙ АНАЛИЗ ==="
    echo ""

    local -a quantitative=("МАКСИМАКС" "АДДИТИВНАЯ_СВЕРТКА" "ИДЕАЛЬНАЯ_ТОЧКА")
    local -a qualitative=("ПАРЕТО" "КОНЪЮНКЦИЯ" "УСТУПКИ" "ЛЕКСИКОГРАФИЧЕСКИЙ")

    # Частота побед (количественные методы)
    declare -A win_counts
    for alt in "${ALTERNATIVES[@]}"; do win_counts["$alt"]=0; done

    for p in "${quantitative[@]}"; do
        local best_value=-999999
        local -a best_alts=()

        for alt in "${ALTERNATIVES[@]}"; do
            local value="${PRINCIPLE_RESULTS[$p,$alt]}"
            [ -z "$value" ] && value=-999999
            if bc_compare "$value" "$best_value" "gt"; then
                best_value="$value"
                best_alts=("$alt")
            elif bc_compare "$value" "$best_value" "eq"; then
                best_alts+=("$alt")
            fi
        done

        for b in "${best_alts[@]}"; do
            win_counts["$b"]=$((win_counts["$b"] + 1))
        done
    done

    echo "3.1 Частота побед (количественные методы):"
    for alt in "${ALTERNATIVES[@]}"; do
        echo "  • $alt: ${win_counts[$alt]}/3"
    done
    echo ""

    # Качественные методы
    declare -A qual_scores
    for alt in "${ALTERNATIVES[@]}"; do qual_scores["$alt"]=0; done

    for p in "${qualitative[@]}"; do
        for alt in "${ALTERNATIVES[@]}"; do
            local r="${PRINCIPLE_RESULTS[$p,$alt]:-0}"
            if bc_compare "$r" "0.5" "gt"; then
                qual_scores["$alt"]=$((qual_scores["$alt"] + 1))
            fi
        done
    done

    echo "3.2 Качественные методы (проходят):"
    for alt in "${ALTERNATIVES[@]}"; do
        echo "  • $alt: ${qual_scores[$alt]}/4"
    done
    echo ""
}

__generate_conclusions() {
    echo "=== ИТОГОВЫЕ ВЫВОДЫ ==="
    echo ""

    local -a counted=("МАКСИМАКС" "АДДИТИВНАЯ_СВЕРТКА" "ИДЕАЛЬНАЯ_ТОЧКА")

    declare -A win_counts
    for alt in "${ALTERNATIVES[@]}"; do win_counts["$alt"]=0; done

    for principle in "${counted[@]}"; do
        local best_value=-999999
        local -a best_alts=()

        for alt in "${ALTERNATIVES[@]}"; do
            local value="${PRINCIPLE_RESULTS[$principle,$alt]}"
            [ -z "$value" ] && value=-999999
            if bc_compare "$value" "$best_value" "gt"; then
                best_value="$value"
                best_alts=("$alt")
            elif bc_compare "$value" "$best_value" "eq"; then
                best_alts+=("$alt")
            fi
        done

        for best_alt in "${best_alts[@]}"; do
            win_counts["$best_alt"]=$((win_counts["$best_alt"] + 1))
        done
    done

    local max_wins=0
    local -a best_alts=()

    for alt in "${ALTERNATIVES[@]}"; do
        local count="${win_counts[$alt]}"
        if [ "$count" -gt "$max_wins" ]; then
            max_wins="$count"
            best_alts=("$alt")
        elif [ "$count" -eq "$max_wins" ] && [ "$count" -gt 0 ]; then
            best_alts+=("$alt")
        fi
    done

    if [ "$max_wins" -gt 0 ] && [ ${#best_alts[@]} -eq 1 ]; then
        local best_alt="${best_alts[0]}"
        echo "Рекомендуемая альтернатива: $best_alt"
        echo "  • Лидер по количественным методам: $max_wins/3"
        echo ""
        echo "Характеристики $best_alt:"
        for crit in "${CRITERIA[@]}"; do
            local orig_val="${DECISION_MATRIX[$best_alt,$crit]:-0}"
            local norm_val="${NORMALIZED_MATRIX[$best_alt,$crit]:-0}"
            LC_NUMERIC=C printf "  %-15s %7.2f  (норм. %.4f)\n" "$crit" "$orig_val" "$norm_val"
        done
    else
        echo "Лидеры: ${best_alts[*]}"
        echo "Каждая побеждает в $max_wins/3 количественных методах."
    fi

    echo ""
}

join_by() {
    local d=${1-} f=${2-}
    if shift 2; then
        LC_NUMERIC=C printf %s "$f" "${@/#/$d}"
    fi
}

__exists_in_array() {
    local -n arr=$1
    local value="$2"

    for item in "${arr[@]}"; do
        if [[ "$item" == "$value" ]]; then
            return 0
        fi
    done
    return 1
}

# === КАЛЬКУЛЯТОР BC ===
bc_init() {
    [[ -n "$BC_PROC_PID" ]] && kill -0 "$BC_PROC_PID" 2>/dev/null && return

    # Создаем именованные каналы (FIFO)
    BC_INPUT=$(mktemp -u)
    BC_OUTPUT=$(mktemp -u)

    mkfifo "$BC_INPUT" 2>/dev/null
    mkfifo "$BC_OUTPUT" 2>/dev/null

    # Запускаем bc в фоновом режиме
    bc -l < "$BC_INPUT" > "$BC_OUTPUT" 2>/dev/null &
    BC_PROC_PID=$!

    exec 5>"$BC_INPUT"  # дескриптор 5 для записи в bc
    exec 6<"$BC_OUTPUT" # дескриптор 6 для чтения из bc

    sleep 0.1

    cat >&5 <<'EOF'
define pow(b, p) { if (p == 0) return 1; if (b == 0) return 0; return e(p*l(b)); }
define sqrt(x) { if (x < 0) return 0; return pow(x, 0.5); }
define abs(x) { if (x < 0) return -x; return x; }
define min(a, b) { if (a < b) return a; return b; }
define max(a, b) { if (a > b) return a; return b; }
EOF

    sleep 0.05
}

bc_write() {
    [[ -z "$BC_PROC_PID" ]] && bc_init
    [[ -z "$BC_PROC_PID" ]] && return 1

    # Записываем в дескриптор 5
    echo "$1" >&5 2>/dev/null || {
        bc_cleanup
        bc_init
        echo "$1" >&5 2>/dev/null
    }
}

bc_read() {
    [[ -z "$BC_PROC_PID" ]] && { echo "0"; return 1; }

    local result
    # Читаем из дескриптора 6
    if read -t 1 -r result <&6 2>/dev/null; then
        echo "$result"
        return 0
    fi
    echo "0"
    return 1
}

bc_calc() {
    local expression="$1" scale="${2:-6}" default="${3:-0}"

    [[ -z "$expression" ]] && { echo "$default"; return; }

    expression=$(echo "$expression" | tr ',' '.' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    bc_write "scale=$scale; $expression"
    local result=$(bc_read)

    [[ -z "$result" || "$result" == *"error"* ]] && { echo "$default"; return; }

    local out
    out=$(LANG=C printf "%.${scale}f" "$result")
    if [[ "$out" == *.* ]]; then
        out=$(echo "$out" | sed -E 's/0+$//; s/\.$//')
    fi
    echo "$out"
}

bc_compare() {
    local a="$1" b="$2" op="$3" bc_op

    case "$op" in
        gt) bc_op=">" ;;
        lt) bc_op="<" ;;
        ge) bc_op=">=" ;;
        le) bc_op="<=" ;;
        eq) bc_op="==" ;;
        ne) bc_op="!=" ;;
        *) echo "1"; return ;;
    esac

    bc_write "$a $bc_op $b"
    [[ "$(bc_read)" == "1" ]]
}

bc_cleanup() {
    [[ -z "$BC_PROC_PID" ]] && return

    # Закрываем дескрипторы 5 и 6
    exec 5>&- 2>/dev/null
    exec 6<&- 2>/dev/null

    # Завершаем процесс
    kill "$BC_PROC_PID" 2>/dev/null
    wait "$BC_PROC_PID" 2>/dev/null 2>&1 || true

    # Удаляем FIFO
    [[ -f "$BC_INPUT" ]] && rm -f "$BC_INPUT" 2>/dev/null
    [[ -f "$BC_OUTPUT" ]] && rm -f "$BC_OUTPUT" 2>/dev/null

    unset BC_PROC_PID BC_INPUT BC_OUTPUT
}

# === УПРАВЛЕНИЕ ДАННЫМИ ===
data_cleanup() {
    ALTERNATIVES=()
    CRITERIA=()
    unset CRITERIA_TYPES 2>/dev/null; declare -gA CRITERIA_TYPES
    unset CRITERIA_WEIGHTS 2>/dev/null; declare -gA CRITERIA_WEIGHTS
    unset DECISION_MATRIX 2>/dev/null; declare -gA DECISION_MATRIX
    unset NORMALIZED_MATRIX 2>/dev/null; declare -gA NORMALIZED_MATRIX
    unset PRINCIPLE_RESULTS 2>/dev/null; declare -gA PRINCIPLE_RESULTS
    unset PRINCIPLE_RANKS 2>/dev/null; declare -gA PRINCIPLE_RANKS

    # Очистка временных файлов
    [[ -n "${PROGRESS_FILE-}" && -f "${PROGRESS_FILE-}" ]] && rm -f "$PROGRESS_FILE" 2>/dev/null
    unset PROGRESS_FILE PROGRESS_PID 2>/dev/null || true

    return 0
}

data_load_default() {
    echo "Загрузка данных из шаблона по умолчанию..." >&2
    if data_import "$DEFAULT_TEMPLATE"; then
        echo "Данные по умолчанию успешно загружены" >&2
        return 0
    else
        echo "КРИТИЧЕСКАЯ ОШИБКА: Не удалось загрузить шаблон по умолчанию" >&2
        return 1
    fi
}

data_import() {
    local template="$1"

    # Предварительная валидация
    if [[ -z "$template" ]]; then
        echo "Ошибка: пустой шаблон для импорта" >&2
        return 1
    fi

    # Временные структуры
    local -a tmp_alternatives tmp_criteria
    local -A tmp_types tmp_weights tmp_matrix
    local current_section=""
    local line_num=0
    local errors=0

    # Сброс параметров
    THRESHOLD=""
    MAIN_CRITERION=""
    CONCESSION_WEIGHT=""

    __ensure_default_parameters() {
        # Установка значений по умолчанию, если параметры не загружены
        : ${THRESHOLD_NORM:=25}      # порог для максимизируемых критериев
        : ${THRESHOLD_ORIG:=110}     # порог для минимизируемых критериев
        : ${MAIN_CRITERION:="${CRITERIA[0]:-Дешевизна}"}
        : ${CONCESSION_WEIGHT:=0.15}

        # Дополнительная проверка: если пороги не установлены из-за парсинга
        if [[ -z "$THRESHOLD_NORM" ]] || [[ "$THRESHOLD_NORM" == "0" ]]; then
            THRESHOLD_NORM=25
        fi

        if [[ -z "$THRESHOLD_ORIG" ]] || [[ "$THRESHOLD_ORIG" == "0" ]]; then
            THRESHOLD_ORIG=110
        fi

        echo "Параметры установлены: нормированный порог=$THRESHOLD_NORM, исходный порог=$THRESHOLD_ORIG" >&2
    }

    # Вспомогательная функция проверки существования
    __exists_in_array() {
        local -n arr=$1
        local value="$2"
        for item in "${arr[@]}"; do
            [[ "$item" == "$value" ]] && return 0
        done
        return 1
    }

    # Вспомогательная функция проверки числового формата
    __is_valid_number() {
        local value="$1"
        # Заменяем запятую на точку для десятичных
        value="${value//,/.}"
        # Проверяем, что это число (целое или дробное, может быть отрицательным)
        [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || [[ "$value" =~ ^-?[0-9]*\.[0-9]+$ ]]
    }

    while IFS= read -r line; do
        ((line_num++))
        line=$(echo "$line" | sed -e 's/^\xEF\xBB\xBF//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi

        case "$current_section" in
            "Альтернативы")
                IFS=',' read -ra items <<< "$line"
                for item in "${items[@]}"; do
                    item=$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ -n "$item" ]]; then
                        tmp_alternatives+=("$item")
                    fi
                done
                ;;

            "Критерии")
                IFS=',' read -ra items <<< "$line"
                for item in "${items[@]}"; do
                    item=$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ -n "$item" ]]; then
                        tmp_criteria+=("$item")
                    fi
                done
                ;;

            "Типы критериев")
                if [[ "$line" =~ ^([^:]+):(min|max)$ ]]; then
                    local crit="${BASH_REMATCH[1]}"
                    local type="${BASH_REMATCH[2]}"
                    crit=$(echo "$crit" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    if ! __exists_in_array tmp_criteria "$crit"; then
                        echo "Ошибка: критерий '$crit' не объявлен (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    tmp_types["$crit"]="$type"
                else
                    echo "Ошибка: некорректный формат типа критерия '$line' (строка $line_num)" >&2
                    echo "  Формат должен быть: Критерий:min или Критерий:max" >&2
                    ((errors++))
                fi
                ;;

            "Веса критериев")
                if [[ "$line" =~ ^([^:]+):([0-9.]+)$ ]]; then
                    local crit="${BASH_REMATCH[1]}"
                    local weight="${BASH_REMATCH[2]}"
                    crit=$(echo "$crit" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    if ! __exists_in_array tmp_criteria "$crit"; then
                        echo "Ошибка: критерий '$crit' не объявлен (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    if ! __is_valid_number "$weight"; then
                        echo "Ошибка: некорректный вес '$weight' (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    # Проверка, что вес положительный
                    if bc_compare "$weight" "0" "le" 2>/dev/null; then
                        echo "Ошибка: неположительный вес '$weight' (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    tmp_weights["$crit"]="$weight"
                else
                    echo "Ошибка формата веса: '$line' (строка $line_num)" >&2
                    ((errors++))
                fi
                ;;

            "Матрица решений")
                if [[ "$line" =~ ^([^:]+):(.+)$ ]]; then
                    local alt="${BASH_REMATCH[1]}"
                    local values_str="${BASH_REMATCH[2]}"
                    alt=$(echo "$alt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    # Проверка существования альтернативы
                    if ! __exists_in_array tmp_alternatives "$alt"; then
                        echo "Ошибка: альтернатива '$alt' не объявлена (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    IFS=',' read -ra values <<< "$values_str"

                    # Проверка количества значений
                    local values_count=${#values[@]}
                    local criteria_count=${#tmp_criteria[@]}

                    if [[ $values_count -ne $criteria_count ]]; then
                        echo "Ошибка: количество оценок ($values_count) не соответствует количеству критериев ($criteria_count) для '$alt' (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    for ((i=0; i<criteria_count; i++)); do
                        local crit="${tmp_criteria[$i]}"
                        local val="${values[$i]// /}"

                        # ССтрогая проверка числового формата
                        if ! __is_valid_number "$val"; then
                            echo "Ошибка: некорректное числовое значение '$val' для альтернативы '$alt', критерия '$crit' (строка $line_num)" >&2
                            ((errors++))
                            continue 2  # Выход из обоих циклов
                        fi

                        # Проверка с помощью bc
                        if ! bc_calc "$val + 0" >/dev/null 2>&1; then
                            echo "Ошибка: не удалось преобразовать '$val' в число для '$alt,$crit' (строка $line_num)" >&2
                            ((errors++))
                            continue 2
                        fi

                        tmp_matrix["$alt,$crit"]="$val"
                    done
                else
                    echo "Ошибка формата матрицы решений: '$line' (строка $line_num)" >&2
                    ((errors++))
                fi
                ;;
            "Параметры")
                # Поддерживаем оба формата: через = и через :
                if [[ "$line" =~ ^([^=:]+)[=:](.+)$ ]]; then
                    local param="${BASH_REMATCH[1]}"
                    local value="${BASH_REMATCH[2]}"
                    param=$(echo "$param" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    case "$param" in
                        "ПОРОГ_НОРМАЛИЗОВАННЫЙ"|"порог_нормализованный")
                            if __is_valid_number "$value"; then
                                THRESHOLD_NORM="$value"
                                echo "Установлен нормированный порог: $value" >&2
                            else
                                echo "Предупреждение: некорректный нормированный порог '$value', используем по умолчанию" >&2
                            fi
                            ;;
                        "ПОРОГ_ИСХОДНЫЙ"|"порог_исходный")
                            if __is_valid_number "$value"; then
                                THRESHOLD_ORIG="$value"
                                echo "Установлен исходный порог: $value" >&2
                            else
                                echo "Предупреждение: некорректный исходный порог '$value', используем по умолчанию" >&2
                            fi
                            ;;
                        "ГЛАВНЫЙ_КРИТЕРИЙ"|"главный_критерий")
                            MAIN_CRITERION="$value"
                            echo "Установлен главный критерий: $value" >&2
                            ;;
                        "ВЕЛИЧИНА_УСТУПКИ"|"величина_уступки")
                            if __is_valid_number "$value"; then
                                CONCESSION_WEIGHT="$value"
                                echo "Установлена величина уступки: $value" >&2
                            else
                                echo "Предупреждение: некорректная величина уступки '$value', используем по умолчанию" >&2
                            fi
                            ;;
                        *)
                            echo "Предупреждение: неизвестный параметр '$param' (строка $line_num)" >&2
                            ;;
                    esac
                else
                    echo "Ошибка формата параметра: '$line' (строка $line_num)" >&2
                    ((errors++))
                fi
                ;;
        esac
    done <<< "$template"

    # Проверяем наличие ошибок
    if [[ $errors -gt 0 ]]; then
        echo "Импорт отменен из-за $errors ошибок" >&2
        return 1
    fi

    # Проверяем полноту данных
    local expected_count=$((${#tmp_alternatives[@]} * ${#tmp_criteria[@]}))
    local actual_count=0
    for key in "${!tmp_matrix[@]}"; do
        ((actual_count++))
    done

    if [[ $expected_count -ne $actual_count ]]; then
        echo "Ошибка: не хватает оценок (ожидается: $expected_count, найдено: $actual_count)" >&2
        return 1
    fi

    # Проверяем, что для всех критериев заданы типы
    for crit in "${tmp_criteria[@]}"; do
        if [[ -z "${tmp_types[$crit]+isset}" ]]; then
            echo "Ошибка: не задан тип для критерия '$crit'" >&2
            return 1
        fi
    done

    # Применение данных
    data_cleanup

    # Копирование данных из временных структур
    ALTERNATIVES=("${tmp_alternatives[@]}")
    CRITERIA=("${tmp_criteria[@]}")

    for key in "${!tmp_types[@]}"; do
        CRITERIA_TYPES["$key"]="${tmp_types[$key]}"
    done

    for key in "${!tmp_weights[@]}"; do
        CRITERIA_WEIGHTS["$key"]="${tmp_weights[$key]}"
    done

    for key in "${!tmp_matrix[@]}"; do
        DECISION_MATRIX["$key"]="${tmp_matrix[$key]}"
    done

    # Параметры по умолчанию
    : ${THRESHOLD:=70}
    : ${MAIN_CRITERION:="${CRITERIA[0]}"}
    : ${CONCESSION_WEIGHT:=0.15}

    # Нормализация весов
    __normalize_weights

    echo "Импорт успешен: ${#ALTERNATIVES[@]} альтернатив, ${#CRITERIA[@]} критериев" >&2

    # Проверяем, что все необходимые переменные установлены
    echo "Отладочная информация о параметрах:" >&2
    echo "  THRESHOLD_NORM=$THRESHOLD_NORM" >&2
    echo "  THRESHOLD_ORIG=$THRESHOLD_ORIG" >&2
    echo "  MAIN_CRITERION=$MAIN_CRITERION" >&2
    echo "  CONCESSION_WEIGHT=$CONCESSION_WEIGHT" >&2

    # Проверяем существование главного критерия
    if ! __exists_in_array tmp_criteria "$MAIN_CRITERION"; then
        echo "Предупреждение: главный критерий '$MAIN_CRITERION' не найден, используем '${tmp_criteria[0]}'" >&2
        MAIN_CRITERION="${tmp_criteria[0]}"
    fi

    __ensure_default_parameters
    return 0
}

__normalize_weights() {
    [[ ${#CRITERIA[@]} -eq 0 ]] && {
        echo "Ошибка: нет критериев для нормализации весов" >&2
        return 1
    }

    local weight_sum=0
    local valid_count=0
    local has_any_positive=0

    # Сначала проверяем и собираем веса
    declare -A temp_weights
    for crit in "${CRITERIA[@]}"; do
        local weight="${CRITERIA_WEIGHTS[$crit]:-0}"

        # Проверка корректности
        if ! bc_compare "$weight" "0" "ge" 2>/dev/null; then
            echo "Ошибка: отрицательный вес для '$crit': '$weight'" >&2
            weight=0
        fi

        temp_weights["$crit"]="$weight"
        weight_sum=$(bc_calc "$weight_sum + $weight")

        if [[ -n "${CRITERIA_WEIGHTS[$crit]+isset}" ]]; then
            ((valid_count++))
            if bc_compare "$weight" "0" "gt" 2>/dev/null; then
                has_any_positive=1
            fi
        fi
    done

    # Если весов нет или все нулевые
    if [[ $valid_count -eq 0 ]] || bc_compare "$has_any_positive" "0" "eq" 2>/dev/null; then
        echo "Внимание: веса не заданы или все равны 0" >&2
        echo "Устанавливается равномерное распределение" >&2

        local equal_weight=$(bc_calc "1 / ${#CRITERIA[@]}")
        for crit in "${CRITERIA[@]}"; do
            CRITERIA_WEIGHTS["$crit"]=$equal_weight
        done
        return 0
    fi

    # Если сумма весов слишком мала
    if bc_compare "$weight_sum" "0.0001" "le" 2>/dev/null; then
        echo "Ошибка: сумма весов слишком мала ($weight_sum)" >&2
        echo "Введите корректно суммирующиеся значения весов" >&2
        return 1
    fi

    # Нормализация при необходимости
    local diff=$(bc_calc "abs($weight_sum - 1)")
    if bc_compare "$diff" "0.0001" "gt" 2>/dev/null; then
        echo "Нормализую веса: сумма была $weight_sum" >&2
        for crit in "${CRITERIA[@]}"; do
            CRITERIA_WEIGHTS["$crit"]=$(bc_calc "${temp_weights[$crit]} / $weight_sum")
        done
    else
        # Копируем исходные веса (уже нормализованы)
        for crit in "${CRITERIA[@]}"; do
            CRITERIA_WEIGHTS["$crit"]="${temp_weights[$crit]}"
        done
    fi

    # Финальная проверка
    local final_sum=0
    for crit in "${CRITERIA[@]}"; do
        final_sum=$(bc_calc "$final_sum + ${CRITERIA_WEIGHTS[$crit]}")
    done

    echo "Нормализация завершена. Сумма весов: $(LANG=C printf "%.6f" "$final_sum")" >&2
    return 0
}

data_edit() {
    local edit_template="$DEFAULT_TEMPLATE"
    local temp_file=$(mktemp /tmp/data_edit_XXXXXX 2>/dev/null) || {
        echo "Ошибка создания временного файла" >&2
        return 1
    }

    # Гарантируем удаление файла при выходе
    trap "rm -f '$temp_file' 2>/dev/null" EXIT INT TERM

    # Записываем шаблон во временный файл
    echo "$edit_template" > "$temp_file"

    # Получаем отредактированные данные
    local edited_data=$(zenity --text-info \
        --title="Редактирование шаблона данных задачи 6" \
        --width=900 --height=700 \
        --font="monospace 11" \
        --editable \
        --filename="$temp_file" 2>/dev/null)

    local zenity_exit_code=$?

    # Очищаем временный файл
    rm -f "$temp_file" 2>/dev/null
    trap - EXIT INT TERM  # Снимаем обработчики

    if [[ $zenity_exit_code -ne 0 ]]; then
        echo "Редактирование отменено пользователем" >&2
        return 1
    fi

    if [[ -z "$edited_data" ]]; then
        zenity --warning \
            --title="Пустые данные" \
            --text="Введены пустые данные. Изменения не сохранены." \
            --width=400 2>/dev/null
        return 1
    fi

    if data_import "$edited_data"; then
        zenity --info \
            --title="Данные обновлены" \
            --text="Шаблон успешно импортирован!\n\n• Альтернатив: ${#ALTERNATIVES[@]}\n• Критериев: ${#CRITERIA[@]}" \
            --width=400 2>/dev/null
        return 0
    else
        zenity --error \
            --title="Ошибка импорта" \
            --text="Не удалось импортировать отредактированный шаблон.\nПроверьте формат данных." \
            --width=500 2>/dev/null
        return 1
    fi
}

data_validate() {
    local errors=0

    if [[ ${#ALTERNATIVES[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы альтернативы" >&2
        errors=1
    fi

    if [[ ${#CRITERIA[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы критерии" >&2
        errors=1
    fi

    # Проверка матрицы решений
    for alt in "${ALTERNATIVES[@]}"; do
        for crit in "${CRITERIA[@]}"; do
            if [[ -z "${DECISION_MATRIX[$alt,$crit]+isset}" ]]; then
                echo "Ошибка: отсутствует значение для альтернативы '$alt', критерия '$crit'" >&2
                errors=1
            fi
        done
    done

    return $errors
}

# === ЗАПУСК ===
deps_check() {
    if ! command -v zenity &>/dev/null; then
        echo "Ошибка: требуется zenity."
        echo "Установите: sudo apt install zenity"
        exit 1
    fi

    if ! command -v bc &>/dev/null; then
        echo "Ошибка: требуется bc."
        echo "Установите: sudo apt install bc"
        exit 1
    fi
}

# === ЗАПУСК ===
deps_check && case " $* " in
  *" calc "*)
      bc_init && \
      data_load_default && \
      (
        subtask1_preprocessing
        subtask2_optimality_principles
        subtask3_final_analysis
      )
      ;;
  *) zenity_main_menu ;;
esac
