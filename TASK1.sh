#!/bin/bash

# === ПЕРЕМЕННЫЕ ===
declare -A RATINGS TASK1_RANKS TASK2_RANKS TASK1_SCORES TASK2_SCORES
declare -A CRITERIA_WEIGHTS CRITERIA_JUSTIFICATION
declare -a ALTERNATIVES EXPERTS CRITERIA
declare CONSISTENCY_THRESHOLD AGGREGATION_METHOD MIN_RANK
declare PROGRESS_FILE PROGRESS_PID bcsc=6

CURRENT_TEMPLATE=""
DEFAULT_TEMPLATE=$(cat <<'EOF'
# ШАБЛОН ДАННЫХ ДЛЯ ЗАДАЧИ 4

[Альтернативы]
UBUNTU, FEDORA, ASTRA_LINUX, ALT_LINUX, CALCULATE_LINUX

[Эксперты]
ДЖУНИОР, МИДДЛ, СЕНЬОР, ЛИД

[Критерии]
СТОИМОСТЬ, СТАБИЛЬНОСТЬ, БЕЗОПАСНОСТЬ, ДОКУМЕНТАЦИЯ, ПОДДЕРЖКА

[Веса критериев]
СТОИМОСТЬ:15
СТАБИЛЬНОСТЬ:25
БЕЗОПАСНОСТЬ:35
ДОКУМЕНТАЦИЯ:15
ПОДДЕРЖКА:10

[Оценки экспертов]

# Базовая "скрытая истина" (не включается в шаблон, только для понимания логики)
# UBUNTU:          10, 8, 8, 9, 9
# FEDORA (prod):   10, 4, 7, 6, 6
# ASTRA_LINUX:      3, 8, 8, 7, 8
# ALT_LINUX:        9, 8, 9, 7, 7
# CALCULATE_LINUX:  8, 8, 7, 6, 6

# ДЖУНИОР: знает в основном популярные западные дистрибутивы (Ubuntu, Fedora),
#          отечественные знает плохо, опирается на слухи и популярность.
ДЖУНИОР:UBUNTU:10.0,8.0,8.0,9.0,9.0
ДЖУНИОР:FEDORA:10.0,6.0,7.5,7.5,6.5
ДЖУНИОР:ASTRA_LINUX:6.0,6.5,7.0,5.0,5.5
ДЖУНИОР:ALT_LINUX:7.0,7.0,7.5,6.0,6.0
ДЖУНИОР:CALCULATE_LINUX:6.0,6.5,6.5,5.5,5.0

# МИДДЛ: опытный админ, специализируется на CALCULATE_LINUX.
МИДДЛ:UBUNTU:9.5,7.5,7.8,8.5,8.5
МИДДЛ:FEDORA:10.0,5.5,7.2,6.5,6.5
МИДДЛ:ASTRA_LINUX:5.0,7.5,7.8,6.5,7.5
МИДДЛ:ALT_LINUX:8.5,7.8,8.5,6.5,7.0
МИДДЛ:CALCULATE_LINUX:8.0,8.1,7.0,6.1,6.0

# СЕНЬОР: сбалансированный, широкоэрудированный специалист.
#         В среднем точнее, чем МИДДЛ, но немного уступает ЛИДу по "попаданию" в реальные значения.
СЕНЬОР:UBUNTU:9.8,7.9,8.1,8.7,8.8
СЕНЬОР:FEDORA:9.8,4.5,6.8,6.2,6.0
СЕНЬОР:ASTRA_LINUX:3.5,8.2,7.7,6.8,8.2
СЕНЬОР:ALT_LINUX:8.8,7.7,9.0,7.1,7.2
СЕНЬОР:CALCULATE_LINUX:8.2,8.1,6.8,6.2,5.8

# ЛИД: ведущий архитектор/эксперт, максимально близок к "истинным" значениям.
ЛИД:UBUNTU:10.0,8.1,8.0,8.9,9.1
ЛИД:FEDORA:10.0,4.2,7.1,6.0,6.1
ЛИД:ASTRA_LINUX:3.0,7.9,8.1,7.0,7.9
ЛИД:ALT_LINUX:9.1,8.1,8.9,7.1,7.0
ЛИД:CALCULATE_LINUX:7.8,7.9,7.1,5.9,6.0

[Параметры]
СОГЛАСОВАННОСТЬ_ПОРОГ=0.70
АГРЕГАЦИЯ_МЕТОД=среднее
МИНИМАЛЬНЫЙ_РАНГ=1

[Обоснование весов]
СТОИМОСТЬ=Важна для российского бизнеса (особенно для SMB), но в долгосрочной перспективе не может перевесить риски простоев и инцидентов безопасности.
СТАБИЛЬНОСТЬ=Критична для production-систем: обновление "раз в год с ломанием конфигураций" (как у Fedora) неприемлемо для крупных инсталляций, предпочтительны LTS и стабильные ветки (Ubuntu LTS, ALT p10).
БЕЗОПАСНОСТЬ=Ключевой приоритет в условиях ужесточения регуляторных требований и роста числа атак; сертификация ФСТЭК/ФСБ и зрелые механизмы MAC дают значимые преимущества.
ДОКУМЕНТАЦИЯ=Ускоряет внедрение и снижает нагрузку на команду, но её недостаток частично компенсируется опытом администраторов и активностью сообщества.
ПОДДЕРЖКА=Коммерческая поддержка важна для крупных организаций и госсектора; для компаний с сильной собственной IT-командой достаточно качественного сообщества и открытых ресурсов, поэтому вес поддержки ниже, чем у безопасности и стабильности.
EOF
)

# === ИНТЕРФЕЙС ===
zenity_show_conditions() {
    if ! data_validate; then
        zenity --error --title="Ошибка данных" \
            --text="Данные не загружены или повреждены.\nЗагрузите данные заново." --width=500 2>/dev/null
        return
    fi

    local conditions_text="ЗАДАЧА 4: ОБРАБОТКА ЭКСПЕРТНЫХ ОЦЕНОК

ЦЕЛЬ:
Преобразовать индивидуальные оценки экспертов в коллективную ранжировку альтернатив.

ПОДЗАДАЧИ:
1. Агрегация индивидуальных оценок экспертов
   - Метод: $AGGREGATION_METHOD
   - Результат: ранжировка R1

2. Агрегация парных сравнений экспертов
   - Матрицы парных сравнений
   - Результат: ранжировка R2

3. Определение весов критериев
   - Ручное назначение с обоснованием
   - Нормализация к 100%

4. Оценка согласованности экспертов
   - Коэффициент конкордации Кендалла (W)
   - Порог: W ≥ $CONSISTENCY_THRESHOLD

5. Сравнение методов агрегации
   - Корреляция Спирмена между R1 и R2

ДАННЫЕ:
• Альтернатив: ${#ALTERNATIVES[@]}
• Экспертов: ${#EXPERTS[@]}
• Критериев: ${#CRITERIA[@]}"

    echo "$conditions_text" | zenity --text-info --title="Задача 4" \
        --width=800 --height=700 --font="monospace 10" 2>/dev/null || true
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
            --title="Задача 4: Экспертные оценки" \
            --text="Действие:" \
            --column="Опция" \
            "▶ Выполнить все задачи" \
            "1. Индивидуальные оценки" \
            "2. Парные сравнения альтернатив" \
            "3. Веса критериев" \
            "4. Согласованность экспертов" \
            "5. Зависимости ранжировок" \
            "✏️ Редактировать данные" \
            "📋 Условия задачи" \
            --width=350 --height=500 2>/dev/null)

        if [ -z "$choice" ]; then
            break
        fi

        case "$choice" in
            "▶ Выполнить все задачи")
                zenity_run_all_tasks
                ;;
            "1. Индивидуальные оценки")
                { subtask1_individual_aggregation; } | zenity --text-info \
                    --title="Задача 1" \
                    --width=600 --height=700 --font="monospace 10" 2>/dev/null || subtask1_individual_aggregation
                ;;
            "2. Парные сравнения альтернатив")
                { subtask2_pairwise_comparison; } | zenity --text-info \
                    --title="Задача 2" \
                    --width=600 --height=700 --font="monospace 10" 2>/dev/null || subtask2_pairwise_comparison
                ;;
            "3. Веса критериев")
                { subtask3_criteria_weights; } | zenity --text-info \
                    --title="Задача 3" \
                    --width=800 --height=700 --font="monospace 10" 2>/dev/null || subtask3_criteria_weights
                ;;
            "4. Согласованность экспертов")
                { subtask4_expert_consistency; } | zenity --text-info \
                    --title="Задача 4" \
                    --width=600 --height=700 --font="monospace 10" 2>/dev/null || subtask4_expert_consistency
                ;;
            "5. Зависимости ранжировок")
                { subtask5_rank_dependencies; } | zenity --text-info \
                    --title="Задача 5" \
                    --width=650 --height=700 --font="monospace 10" 2>/dev/null || subtask5_rank_dependencies
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

    zenity_progress_start "Решение задачи 4" "Подготовка данных..."

    {
        echo "=== РЕШЕНИЕ ЗАДАЧИ 4 ==="
        echo ""

        echo "10" >&3
        echo "# 1. Вычисление индивидуальных оценок..." >&3
        subtask1_individual_aggregation

        echo "30" >&3
        echo "# 2. Сравнение альтернатив парами..."  >&3
        subtask2_pairwise_comparison

        echo "50" >&3
        echo "# 3. Определение весов критериев..."  >&3
        subtask3_criteria_weights

        echo "70" >&3
        echo "# 4. Вычисление согласованности экспертов..." >&3
        subtask4_expert_consistency

        echo "90" >&3
        echo "# 5. Вычисление зависимости ранжировок..." >&3
        subtask5_rank_dependencies

        echo "100" >&3
        echo "# Вычисления завершены" >&3
        sleep 0.5

    } > "$temp_file" 2>&1

    zenity_progress_stop

    cat "$temp_file" | zenity --text-info \
        --title="Решение задачи 4" \
        --width=800 --height=1000 \
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
subtask1_individual_aggregation() {
    echo "ЗАДАЧА 1: ОБОБЩЕННАЯ ОЦЕНКА НА ОСНОВЕ ИНДИВИДУАЛЬНЫХ ОЦЕНОК"
    echo "==========================================================="
    echo ""
    echo "МЕТОД: Агрегация экспертных оценок с учетом весов критериев"
    echo "Агрегирующая функция: $AGGREGATION_METHOD"
    echo ""
    echo "ПАРАМЕТРЫ:"
    echo "  Экспертов: ${#EXPERTS[@]}"
    echo "  Альтернатив: ${#ALTERNATIVES[@]}"
    echo "  Критериев: ${#CRITERIA[@]}"

    local weight_sum=0
    local has_missing_weights=0
    for crit in "${CRITERIA[@]}"; do
        if [[ -n "${CRITERIA_WEIGHTS[$crit]+isset}" ]]; then
            local weight="${CRITERIA_WEIGHTS[$crit]}"
            weight_sum=$(bc_calc "$weight_sum + $weight")
        else
            echo "Предупреждение: вес для критерия '$crit' не задан" >&2
            has_missing_weights=1
        fi
    done
    echo "  Сумма весов критериев: $(LANG=C printf "%.1f" "$weight_sum")%"
    echo ""

    echo "1.1 ВЗВЕШЕННЫЕ ОЦЕНКИ ЭКСПЕРТОВ:"
    echo "--------------------------------"

    local m=${#EXPERTS[@]}
    local n=${#ALTERNATIVES[@]}
    declare -A expert_scores
    declare -A general_scores

    for expert in "${EXPERTS[@]}"; do
        echo "Эксперт: $expert"
        echo "  Альтернатива      Взвешенная оценка"
        echo "  ------------      -----------------"

        for alt in "${ALTERNATIVES[@]}"; do
            local score=$(__calculate_weighted_score "$expert" "$alt")
            expert_scores["$expert,$alt"]=$score
            LANG=C printf "  %-16s %8.4f\n" "$alt" "$score"
        done
        echo ""
    done

    echo "1.2 ИТОГОВЫЕ ОЦЕНКИ АЛЬТЕРНАТИВ (агрегация по экспертам):"
    echo "--------------------------------------------------------"

    local -a agg_scores
    for ((alt_idx=0; alt_idx<n; alt_idx++)); do
        local alt="${ALTERNATIVES[$alt_idx]}"
        local sum=0
        local -a scores

        for expert in "${EXPERTS[@]}"; do
            local score="${expert_scores[$expert,$alt]}"
            scores+=("$score")
            sum=$(bc_calc "$sum + $score")
        done

        case "$AGGREGATION_METHOD" in
            "среднее")
                agg_scores[$alt_idx]=$(bc_calc "$sum / $m")
                ;;
            "медиана")
                # Сортируем оценки
                IFS=$'\n' sorted_scores=($(sort -n <<<"${scores[*]}"))
                unset IFS
                # Для четного числа берем среднее двух центральных
                if [ $((m % 2)) -eq 0 ]; then
                    local mid1=$((m/2 - 1))
                    local mid2=$((m/2))
                    local median=$(bc_calc "(${sorted_scores[$mid1]} + ${sorted_scores[$mid2]}) / 2")
                else
                    local median="${sorted_scores[$((m/2))]}"
                fi
                agg_scores[$alt_idx]=$median
                ;;
            "геом_среднее")
                local product=1
                for score in "${scores[@]}"; do
                    product=$(bc_calc "$product * $score")
                done
                agg_scores[$alt_idx]=$(bc_calc "e(l($product)/$m)")
                ;;
            *)
                agg_scores[$alt_idx]=$(bc_calc "$sum / $m")
                ;;
        esac

        general_scores["$alt"]="${agg_scores[$alt_idx]}"
    done

    echo "  Альтернатива      Итоговая оценка"
    echo "  ------------      ---------------"
    for alt in "${ALTERNATIVES[@]}"; do
        LANG=C printf "  %-16s %8.4f\n" "$alt" "${general_scores[$alt]}"
    done
    echo ""

    echo "1.3 РАНЖИРОВКА АЛЬТЕРНАТИВ:"
    echo "---------------------------"
    echo "(1 - наилучшая альтернатива)"

    # Создаем массив для ранжирования
    local -a scores_array
    for ((i=0; i<n; i++)); do
        scores_array[$i]="${agg_scores[$i]}"
    done

    # Вычисляем ранги с обработкой связей
    local -a ranks_array
    local rank_correction
    __calculate_ranks scores_array ranks_array rank_correction

    # Сортируем для вывода от лучшего к худшему
    local -a sorted_pairs
    for ((i=0; i<n; i++)); do
        local alt="${ALTERNATIVES[$i]}"
        local score="${scores_array[$i]}"
        local rank="${ranks_array[$i]}"
        sorted_pairs+=("$rank:$score:$alt")
    done

    IFS=$'\n' sorted=($(LANG=C printf "%s\n" "${sorted_pairs[@]}" | sort -t: -k1 -n))
    unset IFS

    for item in "${sorted[@]}"; do
        IFS=':' read -r rank score alt <<< "$item"

        TASK1_RANKS["$alt"]=$rank
        TASK1_SCORES["$alt"]=$score

        if bc_compare "$rank" "${rank%.*}" "eq"; then
            LANG=C printf "  %d. %-16s (оценка: %6.4f)\n" "$rank" "$alt" "$score"
        else
            LANG=C printf "  %.1f. %-15s (оценка: %6.4f)\n" "$rank" "$alt" "$score"
        fi
    done

    # Находим лучшую альтернативу
    local best_alt="${ALTERNATIVES[0]}"
    local best_score="${general_scores[$best_alt]}"
    for alt in "${ALTERNATIVES[@]:1}"; do
        if bc_compare "${general_scores[$alt]}" "$best_score" "gt"; then
            best_alt="$alt"
            best_score="${general_scores[$alt]}"
        fi
    done
}

subtask2_pairwise_comparison() {
    echo "ЗАДАЧА 2: ОБОБЩЕННАЯ ОЦЕНКА НА ОСНОВЕ ПАРНЫХ СРАВНЕНИЙ"
    echo "======================================================"
    echo ""
    echo "МЕТОД: Классический метод парных сравнений Кендалла"
    echo "       (строится матрица предпочтений для каждого эксперта)"
    echo ""
    echo "ПАРАМЕТРЫ:"
    echo "  Экспертов: ${#EXPERTS[@]}"
    echo "  Альтернатив: ${#ALTERNATIVES[@]}"
    echo ""

    local m=${#EXPERTS[@]}
    local n=${#ALTERNATIVES[@]}
    declare -A pref_matrices aggregated_matrix
    declare -A preference_scores

    echo "2.1 МАТРИЦЫ ПАРНЫХ СРАВНЕНИЙ ЭКСПЕРТОВ:"
    echo "--------------------------------------"
    echo "(+1: строка лучше столбца, -1: строка хуже столбца, 0: равны)"
    echo ""

    local max_name_len=10
    for alt in "${ALTERNATIVES[@]}"; do
        if [ ${#alt} -gt $max_name_len ]; then
            max_name_len=${#alt}
        fi
    done
    max_name_len=$((max_name_len + 2))

    # Строим матрицы парных сравнений для каждого эксперта
    for expert in "${EXPERTS[@]}"; do
        echo "Эксперт: $expert"
        echo "Матрица предпочтений:"
        echo ""

        # Заголовок
        LANG=C printf "%*s" $max_name_len " "
        for alt in "${ALTERNATIVES[@]}"; do
            LANG=C printf " %-6s" "$alt"
        done
        echo ""

        LANG=C printf "%*s" $max_name_len " "
        for alt in "${ALTERNATIVES[@]}"; do
            LANG=C printf " %-6s" "------"
        done
        echo ""

        for alt_i in "${ALTERNATIVES[@]}"; do
            LANG=C printf "%-*s" $max_name_len "$alt_i"

            for alt_j in "${ALTERNATIVES[@]}"; do
                if [[ "$alt_i" == "$alt_j" ]]; then
                    pref_matrices["$expert,$alt_i,$alt_j"]=0
                    LANG=C printf " %-6s" "0"
                else
                    # Используем взвешенные оценки для сравнения
                    local score_i=$(__calculate_weighted_score "$expert" "$alt_i")
                    local score_j=$(__calculate_weighted_score "$expert" "$alt_j")

                    if bc_compare "$score_i" "$score_j" "gt"; then
                        pref_matrices["$expert,$alt_i,$alt_j"]=1
                        LANG=C printf " %-6s" "+1"
                    elif bc_compare "$score_i" "$score_j" "lt"; then
                        pref_matrices["$expert,$alt_i,$alt_j"]=-1
                        LANG=C printf " %-6s" "-1"
                    else
                        pref_matrices["$expert,$alt_i,$alt_j"]=0
                        LANG=C printf " %-6s" "0"
                    fi
                fi
            done
            echo ""
        done
        echo ""
    done

    echo "2.2 ОБОБЩЕННАЯ МАТРИЦА ПРЕДПОЧТЕНИЙ:"
    echo "-----------------------------------"
    echo ""

    # Суммируем матрицы всех экспертов
    for alt_i in "${ALTERNATIVES[@]}"; do
        for alt_j in "${ALTERNATIVES[@]}"; do
            if [[ "$alt_i" == "$alt_j" ]]; then
                aggregated_matrix["$alt_i,$alt_j"]=0
                continue
            fi

            local sum=0
            for expert in "${EXPERTS[@]}"; do
                sum=$(bc_calc "$sum + ${pref_matrices[$expert,$alt_i,$alt_j]}")
            done
            aggregated_matrix["$alt_i,$alt_j"]=$sum
        done
    done

    # Выводим обобщенную матрицу
    LANG=C printf "%*s" $max_name_len " "
    for alt in "${ALTERNATIVES[@]}"; do
        LANG=C printf " %-6s" "$alt"
    done
    LANG=C printf "   %-10s\n" "Сумма"
    echo ""

    for alt_i in "${ALTERNATIVES[@]}"; do
        LANG=C printf "%-*s" $max_name_len "$alt_i"
        local row_sum=0

        for alt_j in "${ALTERNATIVES[@]}"; do
            local val="${aggregated_matrix[$alt_i,$alt_j]}"
            LANG=C printf " %-6s" "$val"
            row_sum=$(bc_calc "$row_sum + $val")
        done

        preference_scores["$alt_i"]=$row_sum
        LANG=C printf "   %-10s\n" "$row_sum"
    done

    echo "2.3 РАНЖИРОВКА ПО СУММЕ ПРЕДПОЧТЕНИЙ:"
    echo "------------------------------------"
    echo "(чем больше сумма, тем лучше альтернатива)"

    # Преобразуем предпочтения в массив для ранжирования
    local -a pref_scores_array
    for ((i=0; i<n; i++)); do
        pref_scores_array[$i]="${preference_scores[${ALTERNATIVES[$i]}]}"
    done

    # Ранжируем с обработкой связанных рангов
    local -a pref_ranks_array
    local rank_correction
    __calculate_ranks pref_scores_array pref_ranks_array rank_correction

    echo "  Альтернатива      Сумма предпочтений   Ранг"
    echo "  ------------      -------------------   ----"

    # Сортируем для наглядного вывода
    local -a sorted_pairs
    for ((i=0; i<n; i++)); do
        local alt="${ALTERNATIVES[$i]}"
        local score="${pref_scores_array[$i]}"
        local rank="${pref_ranks_array[$i]}"
        sorted_pairs+=("$rank:$score:$alt")
    done

    IFS=$'\n' sorted=($(LANG=C printf "%s\n" "${sorted_pairs[@]}" | sort -t: -k1 -n))
    unset IFS

    for item in "${sorted[@]}"; do
        IFS=':' read -r rank score alt <<< "$item"

        TASK2_RANKS["$alt"]=$rank
        TASK2_SCORES["$alt"]=$score

        LANG=C printf "  %-16s %12d %12s\n" "$alt" "$score" "$rank"
    done
    echo ""

    # Находим лучшую альтернативу
    local best_alt="${ALTERNATIVES[0]}"
    local best_score="${TASK2_SCORES[$best_alt]}"
    for alt in "${ALTERNATIVES[@]:1}"; do
        if bc_compare "${TASK2_SCORES[$alt]}" "$best_score" "gt"; then
            best_alt="$alt"
            best_score="${TASK2_SCORES[$alt]}"
        fi
    done
}

subtask3_criteria_weights() {
    echo "ЗАДАЧА 3: ОПРЕДЕЛЕНИЕ ОТНОСИТЕЛЬНЫХ ВЕСОВ КРИТЕРИЕВ"
    echo "=================================================="
    echo ""
    echo "МЕТОД: Назначение весов вручную с последующей нормализацией"
    echo "       и анализом чувствительности"
    echo ""

    if [ ${#CRITERIA[@]} -eq 0 ]; then
        echo "Критерии не заданы."
        return
    fi

    echo "3.1 ТАБЛИЦА ВЕСОВ КРИТЕРИЕВ:"
    echo "---------------------------"

    local total_weight=0
    for crit in "${CRITERIA[@]}"; do
        total_weight=$(bc_calc "$total_weight + ${CRITERIA_WEIGHTS[$crit]}")
    done

    echo "  Критерий          Исходный вес   Нормированный вес (%)"
    echo "  ---------          ------------   --------------------"

    for crit in "${CRITERIA[@]}"; do
        local weight="${CRITERIA_WEIGHTS[$crit]}"
        local norm_weight=$(bc_calc "$weight * 100 / $total_weight")
        LANG=C printf "  %-16s %12.1f %20.1f\n" "$crit" "$weight" "$norm_weight"
    done

    echo ""
    echo "  Сумма весов: $(LANG=C printf "%.1f" "$total_weight")"
    if bc_compare "$total_weight" "100" "eq"; then
        echo "  Статус: корректна (100%)"
    else
        echo "  Статус: требует нормализации до 100%"
    fi
    echo ""

    echo "3.2 ОБОСНОВАНИЕ ВЕСОВ КРИТЕРИЕВ:"
    echo "--------------------------------"

    for crit in "${CRITERIA[@]}"; do
        echo "  Критерий: $crit"
        echo "  Вес: $(LANG=C printf "%.1f" "${CRITERIA_WEIGHTS[$crit]}")"
        echo "  Обоснование: ${CRITERIA_JUSTIFICATION[$crit]}"
        echo ""
    done

    echo "3.3 АНАЛИЗ ЧУВСТВИТЕЛЬНОСТИ ВЕСОВ:"
    echo "----------------------------------"

    if [ ${#ALTERNATIVES[@]} -gt 0 ] && [ ${#EXPERTS[@]} -gt 0 ]; then
        local test_alt="${ALTERNATIVES[0]}"
        local test_expert="${EXPERTS[0]}"

        echo "  Тестовая альтернатива: $test_alt"
        echo "  Эксперт: $test_expert"
        echo ""

        # Сохраняем исходные веса
        declare -A original_weights
        for crit in "${CRITERIA[@]}"; do
            original_weights["$crit"]="${CRITERIA_WEIGHTS[$crit]}"
        done

        # Исходная оценка
        local original_score=$(__calculate_weighted_score "$test_expert" "$test_alt")
        echo "  Исходная взвешенная оценка: $(LANG=C printf "%.4f" "$original_score")"
        echo ""

        # Сценарий 1: Равномерные веса
        echo "  Сценарий 1: Равномерное распределение весов"
        local equal_weight=$(bc_calc "100 / ${#CRITERIA[@]}")
        for crit in "${CRITERIA[@]}"; do
            CRITERIA_WEIGHTS["$crit"]=$equal_weight
        done
        local scenario1_score=$(__calculate_weighted_score "$test_expert" "$test_alt")
        local change1=$(bc_calc "($scenario1_score - $original_score) / $original_score * 100")
        LANG=C printf "    Новая оценка: %.4f (изменение: %+.2f%%)\n" "$scenario1_score" "$change1"
        echo ""

        # Сценарий 2: Акцент на первом критерии
        echo "  Сценарий 2: Акцент на критерии '${CRITERIA[0]}'"
        CRITERIA_WEIGHTS["${CRITERIA[0]}"]=60
        local remaining=$(bc_calc "40 / (${#CRITERIA[@]} - 1)")
        for ((i=1; i<${#CRITERIA[@]}; i++)); do
            CRITERIA_WEIGHTS["${CRITERIA[$i]}"]=$remaining
        done
        local scenario2_score=$(__calculate_weighted_score "$test_expert" "$test_alt")
        local change2=$(bc_calc "($scenario2_score - $original_score) / $original_score * 100")
        LANG=C printf "    Новая оценка: %.4f (изменение: %+.2f%%)\n" "$scenario2_score" "$change2"
        echo ""

        # Восстанавливаем исходные веса
        for crit in "${CRITERIA[@]}"; do
            CRITERIA_WEIGHTS["$crit"]="${original_weights[$crit]}"
        done

        echo "  ВЫВОД: Изменение весов критериев существенно влияет на итоговые оценки."
        echo "         Важность обоснования весов подтверждена анализом чувствительности."
    else
        echo "  Недостаточно данных для анализа чувствительности."
    fi
}

subtask4_expert_consistency() {

echo "ЗАДАЧА 4: ОЦЕНКА СОГЛАСОВАННОСТИ МНЕНИЙ ЭКСПЕРТОВ"
echo "================================================="
echo ""
echo "Используется коэффициент конкордации Кендалла (W)"
echo ""

local m=${#EXPERTS[@]}
local n=${#ALTERNATIVES[@]}

echo "Экспертов: $m"
echo "Альтернатив: $n"
echo "Уровень значимости α = 0.05"
echo ""

if [[ $m -lt 2 || $n -lt 2 ]]; then
  echo "Ошибка: требуется минимум 2 эксперта и 2 альтернативы."
  return
fi

echo "4.1 РАНГИ АЛЬТЕРНАТИВ У КАЖДОГО ЭКСПЕРТА (по интегральной взвешенной оценке):"
echo "--------------------------------------------------------------------------"

declare -A expert_ranks
local total_ties_correction=0   # Σ Ti (поправки за связанные ранги по экспертам)

for expert in "${EXPERTS[@]}"; do
  echo "Эксперт: $expert"
  echo " Альтернатива     Оценка     Ранг"
  echo " ------------  ----------  ------"

  local -a exp_scores=()
  local -a exp_ranks=()
  local exp_correction=0

  for ((i=0; i<n; i++)); do
    local alt="${ALTERNATIVES[$i]}"
    # Более корректно: ранжируем альтернативы по интегральной (взвешенной) оценке эксперта
    exp_scores[$i]="$(__calculate_weighted_score "$expert" "$alt")"
  done

  __calculate_ranks exp_scores exp_ranks exp_correction
  total_ties_correction=$(bc_calc "$total_ties_correction + $exp_correction")

  for ((i=0; i<n; i++)); do
    local alt="${ALTERNATIVES[$i]}"
    expert_ranks["$expert,$alt"]="${exp_ranks[$i]}"
    LANG=C printf " %-12s  %10.4f  %6s\n" "$alt" "${exp_scores[$i]}" "${exp_ranks[$i]}"
  done

  echo ""
done

echo "4.2 СУММЫ РАНГОВ ПО АЛЬТЕРНАТИВАМ:"
echo "---------------------------------"

declare -A rank_sums
echo " Альтернатива     Σ рангов"
echo " ------------  ------------"

for alt in "${ALTERNATIVES[@]}"; do
  local sum=0
  for expert in "${EXPERTS[@]}"; do
    sum=$(bc_calc "$sum + ${expert_ranks[$expert,$alt]}")
  done
  rank_sums["$alt"]="$sum"
  LANG=C printf " %-12s  %12.4f\n" "$alt" "$sum"
done

echo ""
echo "4.3 ВЫЧИСЛЕНИЕ W (Кендалл):"
echo "---------------------------"

# r̄ = m*(n+1)/2
local mean_sum
mean_sum=$(bc_calc "$m*($n+1)/2")
echo "Средняя сумма рангов r̄ = m*(n+1)/2 = $(LANG=C printf "%.4f" "$mean_sum")"

# S = Σ (Rj - r̄)^2
local S=0
for alt in "${ALTERNATIVES[@]}"; do
  local dev
  dev=$(bc_calc "${rank_sums[$alt]} - $mean_sum")
  local dev2
  dev2=$(bc_calc "($dev)*($dev)")
  S=$(bc_calc "$S + $dev2")
done

echo "S = Σ (Rj - r̄)^2 = $(LANG=C printf "%.6f" "$S")"
echo "ΣTi (поправка за связанные ранги) = $(LANG=C printf "%.6f" "$total_ties_correction")"

# Den = m^2*(n^3 - n) - m*ΣTi
local n3_minus_n
n3_minus_n=$(bc_calc "$n*$n*$n - $n" 0)
local denominator
denominator=$(bc_calc "$m*$m*($n3_minus_n) - $m*($total_ties_correction)")

local W=0
if bc_compare "$denominator" "0.0000001" "gt"; then
  #echo "DEBUG: mean_sum=$mean_sum S=$S n3_minus_n=$n3_minus_n denom=$denominator W_raw=$W"
  W=$(bc_calc "12*$S / $denominator" 6)
else
  W=0
fi

# Ограничим W в [0;1] на случай численных артефактов
if bc_compare "$W" "0" "lt"; then W=0; fi
if bc_compare "$W" "1" "gt"; then W=1; fi

echo ""
echo "Формула (с учётом связанных рангов):"
echo "W = 12*S / ( m^2*(n^3 - n) - m*ΣTi )"
echo "W = $(LANG=C printf "%.6f" "$W")"
echo ""

echo "4.4 ПРОВЕРКА ЗНАЧИМОСТИ (χ²):"
echo "-----------------------------"
echo "Статистика: χ² = m*(n-1)*W, степени свободы k = n-1"

local df=$((n-1))
local chi2_stat
chi2_stat=$(bc_calc "$m*($n-1)*$W" 6)
echo "χ² = $(LANG=C printf "%.6f" "$chi2_stat"), k = $df"

# Критические значения χ²(0.95, k) для α=0.05 (правая область), k=1..30
local chi2_crit=""
case "$df" in
  1)  chi2_crit="3.841" ;;
  2)  chi2_crit="5.991" ;;
  3)  chi2_crit="7.815" ;;
  4)  chi2_crit="9.488" ;;
  5)  chi2_crit="11.070" ;;
  6)  chi2_crit="12.592" ;;
  7)  chi2_crit="14.067" ;;
  8)  chi2_crit="15.507" ;;
  9)  chi2_crit="16.919" ;;
  10) chi2_crit="18.307" ;;
  11) chi2_crit="19.675" ;;
  12) chi2_crit="21.026" ;;
  13) chi2_crit="22.362" ;;
  14) chi2_crit="23.685" ;;
  15) chi2_crit="24.996" ;;
  16) chi2_crit="26.296" ;;
  17) chi2_crit="27.587" ;;
  18) chi2_crit="28.869" ;;
  19) chi2_crit="30.144" ;;
  20) chi2_crit="31.410" ;;
  21) chi2_crit="32.671" ;;
  22) chi2_crit="33.924" ;;
  23) chi2_crit="35.172" ;;
  24) chi2_crit="36.415" ;;
  25) chi2_crit="37.652" ;;
  26) chi2_crit="38.885" ;;
  27) chi2_crit="40.113" ;;
  28) chi2_crit="41.337" ;;
  29) chi2_crit="42.557" ;;
  30) chi2_crit="43.773" ;;
  *)  chi2_crit="" ;;
esac

if [[ -n "$chi2_crit" ]]; then
  echo "Критическое χ²(0.95, k=$df) = $chi2_crit"
  if bc_compare "$chi2_stat" "$chi2_crit" "gt"; then
    echo "Вывод: согласованность статистически значима при α=0.05 (отвергается H0 об отсутствии согласованности)."
  else
    echo "Вывод: статистической значимости при α=0.05 не выявлено (H0 не отвергается)."
  fi
else
  echo "Предупреждение: нет табличного χ² для k=$df (добавьте значение в case)."
fi

echo ""
echo "4.5 ИНТЕРПРЕТАЦИЯ W:"
echo "--------------------"
local absW="$W"
if bc_compare "$absW" "0.9" "ge"; then
  echo "W ≥ 0.9: очень высокая согласованность."
elif bc_compare "$absW" "0.7" "ge"; then
  echo "0.7 ≤ W < 0.9: высокая согласованность."
elif bc_compare "$absW" "0.5" "ge"; then
  echo "0.5 ≤ W < 0.7: средняя согласованность."
elif bc_compare "$absW" "0.3" "ge"; then
  echo "0.3 ≤ W < 0.5: низкая согласованность."
else
  echo "W < 0.3: очень низкая согласованность."
fi

echo ""
}

subtask5_rank_dependencies() {
    echo "ЗАДАЧА 5: ОПРЕДЕЛЕНИЕ ЗАВИСИМОСТЕЙ МЕЖДУ РАНЖИРОВКАМИ"
    echo "====================================================="
    echo ""
    echo "МЕТОД: Коэффициент корреляции Спирмена (ρ)"
    echo "       с поправками на связанные ранги"
    echo ""
    echo "СРАВНИВАЕМЫЕ РАНЖИРОВКИ:"
    echo "  Метод 1: Индивидуальные оценки экспертов (задача 1)"
    echo "  Метод 2: Парные сравнения (задача 2)"
    echo ""

    # Убедимся, что ранги вычислены
    if [ ${#TASK1_RANKS[@]} -eq 0 ] || [ ${#TASK2_RANKS[@]} -eq 0 ]; then
        echo "Выполняем вычисления рангов..."
        subtask1_individual_aggregation > /dev/null 2>&1
        subtask2_pairwise_comparison > /dev/null 2>&1
    fi

    local n=${#ALTERNATIVES[@]}

    echo "5.1 ТАБЛИЦА РАНГОВ И РАЗНОСТЕЙ:"
    echo "------------------------------"

    echo "  Альтернатива      Ранг(Метод1)   Ранг(Метод2)   d = R1-R2   d²"
    echo "  ------------      ------------   ------------   ---------   --"

    local sum_d2=0
    local -a ranks1 ranks2

    for ((i=0; i<n; i++)); do
        local alt="${ALTERNATIVES[$i]}"
        local rank1="${TASK1_RANKS[$alt]}"
        local rank2="${TASK2_RANKS[$alt]}"

        ranks1[$i]="$rank1"
        ranks2[$i]="$rank2"

        local d=$(bc_calc "$rank1 - $rank2")
        local d2=$(bc_calc "$d * $d")
        sum_d2=$(bc_calc "$sum_d2 + $d2")

        LANG=C printf "  %-16s %12.2f %14.2f %12.2f %8.2f\n" \
            "$alt" "$rank1" "$rank2" "$d" "$d2"
    done

    echo ""
    echo "  Σd² = $(LANG=C printf "%.4f" "$sum_d2")"
    echo "  n = $n"
    echo ""

    echo "5.2 ПОПРАВКИ НА СВЯЗАННЫЕ РАНГИ:"
    echo "--------------------------------"

    local correction1=$(__calculate_tied_correction ranks1)
    local correction2=$(__calculate_tied_correction ranks2)

    echo "  Поправка для метода 1 (T₁): $(LANG=C printf "%.4f" "$correction1")"
    echo "  Поправка для метода 2 (T₂): $(LANG=C printf "%.4f" "$correction2")"
    echo "  Суммарная поправка: $(LANG=C printf "%.4f" "$(bc_calc "$correction1 + $correction2")")"
    echo ""

    echo "5.3 РАСЧЕТ КОЭФФИЦИЕНТА КОРРЕЛЯЦИИ СПИРМЕНА:"
    echo "------------------------------------------"

    local numerator=$(bc_calc "6 * $sum_d2 + $correction1 + $correction2")
    local denominator=$(bc_calc "$n * ($n * $n - 1)")
    local rho=0

    if bc_compare "$denominator" "0" "gt"; then
        rho=$(bc_calc "1 - $numerator / $denominator")
    fi

    echo "  Формула: ρ = 1 - (6Σd² + T₁ + T₂) / [n(n²-1)]"
    echo "  ρ = 1 - (6×$(LANG=C printf "%.4f" "$sum_d2") + $(LANG=C printf "%.4f" "$correction1") + $(LANG=C printf "%.4f" "$correction2")) / [$n×($n²-1)]"
    echo "  ρ = $(LANG=C printf "%.4f" "$rho")"
    echo ""

    echo "5.4 ИНТЕРПРЕТАЦИЯ КОЭФФИЦИЕНТА ρ:"
    echo "--------------------------------"

    local abs_rho=$(bc_calc "abs($rho)")

    if bc_compare "$abs_rho" "0.9" "ge"; then
        if bc_compare "$rho" "0" "gt"; then
            echo "  Очень сильная положительная корреляция"
            echo "  Методы дают практически идентичные результаты"
        else
            echo "  Очень сильная отрицательная корреляция"
            echo "  Методы дают противоположные результаты"
        fi
    elif bc_compare "$abs_rho" "0.7" "ge"; then
        if bc_compare "$rho" "0" "gt"; then
            echo "  Сильная положительная корреляция"
            echo "  Методы дают схожие результаты"
        else
            echo "  Сильная отрицательная корреляция"
            echo "  Методы противоречат друг другу"
        fi
    elif bc_compare "$abs_rho" "0.5" "ge"; then
        if bc_compare "$rho" "0" "gt"; then
            echo "  Умеренная положительная корреляция"
            echo "  Есть существенное сходство между методами"
        else
            echo "  Умеренная отрицательная корреляция"
            echo "  Методы показывают обратную зависимость"
        fi
    elif bc_compare "$abs_rho" "0.3" "ge"; then
        if bc_compare "$rho" "0" "gt"; then
            echo "  Слабая положительная корреляция"
            echo "  Методы дают различные результаты"
        else
            echo "  Слабая отрицательная корреляция"
            echo "  Методы слабо противоречат друг другу"
        fi
    else
        echo "  Очень слабая корреляция"
        echo "  Методы практически не связаны"
    fi
}

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
__calculate_weighted_score() {
    local expert="$1"
    local alt="$2"
    local weighted_sum=0
    local total_weight=0

    for crit in "${CRITERIA[@]}"; do
        local weight="${CRITERIA_WEIGHTS[$crit]}"
        local score="${RATINGS[$expert,$alt,$crit]}"
        weighted_sum=$(bc_calc "$weighted_sum + $score * $weight")
        total_weight=$(bc_calc "$total_weight + $weight")
    done

    if bc_compare "$total_weight" "0.001" "gt"; then
        echo $(bc_calc "$weighted_sum / $total_weight")
    else
        echo "0"
    fi
}

__calculate_tied_correction() {
    local -n values_ref=$1
    local correction=0

    # Подсчет частот уникальных значений
    declare -A freq
    for val in "${values_ref[@]}"; do
        key=$(LANG=C printf "%.10f" "$val" | sed 's/0*$//;s/\.$//')
        freq["$key"]=$((${freq["$key"]:-0} + 1))
    done

    # Вычисляем Σ(t³ - t)/12
    for count in "${freq[@]}"; do
        if [ $count -gt 1 ]; then
            correction=$(bc_calc "$correction + ($count^3 - $count)/12")
        fi
    done

    echo "$correction"
}

__calculate_ranks() {
    local -n values_arr=$1
    local -n ranks_arr=$2
    local -n correction_var=$3

    local n=${#values_arr[@]}

    # Создаем массив индексов и сортируем по убыванию значений
    local -a indices=($(seq 0 $((n-1))))

    # Сортировка пузырьком по убыванию
    for ((i=0; i<n-1; i++)); do
        for ((j=0; j<n-i-1; j++)); do
            local idx1=${indices[$j]}
            local idx2=${indices[$((j+1))]}
            if bc_compare "${values_arr[$idx1]}" "${values_arr[$idx2]}" "lt"; then
                indices[$j]=$idx2
                indices[$((j+1))]=$idx1
            fi
        done
    done

    local i=0
    correction_var=0

    # Присваиваем ранги с учетом связей
    while [ $i -lt $n ]; do
        local current_idx=${indices[$i]}
        local current_val="${values_arr[$current_idx]}"
        local j=$i

        # Находим конец группы одинаковых значений
        while [ $((j+1)) -lt $n ]; do
            local next_idx=${indices[$((j+1))]}
            local next_val="${values_arr[$next_idx]}"
            if ! bc_compare "$current_val" "$next_val" "eq"; then
                break
            fi
            j=$((j+1))
        done

        local group_size=$((j - i + 1))
        local first_rank=$((i + 1))
        local last_rank=$((j + 1))
        local avg_rank=$(bc_calc "($first_rank + $last_rank) / 2")

        # Присваиваем средний ранг всем элементам группы
        for ((k=i; k<=j; k++)); do
            local idx=${indices[$k]}
            ranks_arr[$idx]=$avg_rank
        done

        # Вычисляем коррекцию для связанных рангов
        if [ $group_size -gt 1 ]; then
            local group_corr=$(bc_calc "($group_size^3 - $group_size) / 12")
            correction_var=$(bc_calc "$correction_var + $group_corr")
        fi

        i=$((j + 1))
    done
}

# === КАЛЬКУЛЯТОР ===
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
define round(x, s) { auto r; r = scale; scale = s; x = x/1; scale = r; return x; }
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
    local expression="$1" scale="${2:-$bcsc}" default="${3:-0}"

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
    # Остановка всех фоновых процессов
    zenity_progress_stop 2>/dev/null
    bc_cleanup 2>/dev/null

    # Очистка индексных массивов
    ALTERNATIVES=()
    EXPERTS=()
    CRITERIA=()

    # Очистка ассоциативных массивов
    unset CRITERIA_WEIGHTS 2>/dev/null; declare -gA CRITERIA_WEIGHTS
    unset CRITERIA_JUSTIFICATION 2>/dev/null; declare -gA CRITERIA_JUSTIFICATION
    unset RATINGS 2>/dev/null; declare -gA RATINGS
    unset TASK1_RANKS 2>/dev/null; declare -gA TASK1_RANKS
    unset TASK2_RANKS 2>/dev/null; declare -gA TASK2_RANKS
    unset TASK1_SCORES 2>/dev/null; declare -gA TASK1_SCORES
    unset TASK2_SCORES 2>/dev/null; declare -gA TASK2_SCORES

    # Сброс скалярных переменных
    CONSISTENCY_THRESHOLD=""
    AGGREGATION_METHOD=""
    MIN_RANK=""
    CURRENT_TEMPLATE=""

    # Очистка временных файлов и переменных
    [[ -n "${PROGRESS_FILE-}" && -f "${PROGRESS_FILE-}" ]] && rm -f "$PROGRESS_FILE" 2>/dev/null
    unset PROGRESS_FILE PROGRESS_PID BC_PROC_PID BC_INPUT BC_OUTPUT 2>/dev/null || true

    # Закрытие дескрипторов с проверкой существования
    for fd in 3 4 5 6; do
        if { true >&$fd; } 2>/dev/null; then
            exec {fd}>&- 2>/dev/null || true
        fi
    done

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
    local -a tmp_alternatives tmp_experts tmp_criteria
    local -A tmp_weights tmp_justifications tmp_ratings
    local tmp_consistency_threshold tmp_aggregation_method tmp_min_rank
    local tmp_template="$template"

    # Сброс параметров
    local current_section=""
    local line_num=0
    local errors=0
    local -A seen_alternatives seen_experts seen_criteria

    # Вспомогательная функция проверки уникальности
    __check_unique_tmp() {
        local -n arr_ref=$1
        local value="$2"
        local type="$3"
        local line_num="$4"

        for existing in "${arr_ref[@]}"; do
            if [[ "$existing" == "$value" ]]; then
                echo "Ошибка: дубликат $type '$value' (строка $line_num)" >&2
                return 1
            fi
        done
        return 0
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

    while IFS= read -r line; do
        ((line_num++))

        # Очистка строки
        line=$(echo "$line" | sed -e 's/^\xEF\xBB\xBF//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        # Пропуск пустых строк и комментариев
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Определение секции
        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi

        # Обработка секций
        case "$current_section" in
            "Альтернативы")
                IFS=',' read -ra items <<< "$line"
                for item in "${items[@]}"; do
                    item=$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ -n "$item" ]]; then
                        if ! __check_unique_tmp tmp_alternatives "$item" "альтернативы" "$line_num"; then
                            ((errors++))
                            continue
                        fi
                        tmp_alternatives+=("$item")
                    fi
                done
                ;;

            "Эксперты")
                IFS=',' read -ra items <<< "$line"
                for item in "${items[@]}"; do
                    item=$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ -n "$item" ]]; then
                        if ! __check_unique_tmp tmp_experts "$item" "экспертов" "$line_num"; then
                            ((errors++))
                            continue
                        fi
                        tmp_experts+=("$item")
                    fi
                done
                ;;

            "Критерии")
                IFS=',' read -ra items <<< "$line"
                for item in "${items[@]}"; do
                    item=$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ -n "$item" ]]; then
                        if ! __check_unique_tmp tmp_criteria "$item" "критериев" "$line_num"; then
                            ((errors++))
                            continue
                        fi
                        tmp_criteria+=("$item")
                    fi
                done
                ;;

            "Веса критериев")
                if [[ "$line" =~ ^([^:]+):([0-9.]+)$ ]]; then
                    local crit="${BASH_REMATCH[1]}"
                    local weight="${BASH_REMATCH[2]}"
                    crit=$(echo "$crit" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    # Проверка существования критерия
                    if ! __exists_in_array tmp_criteria "$crit"; then
                        echo "Ошибка: критерий '$crit' не объявлен (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    # Проверка числового значения
                    if [[ ! "$weight" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                        echo "Ошибка: некорректный вес '$weight' (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    tmp_weights["$crit"]="$weight"
                else
                    echo "Ошибка формата веса: '$line' (строка $line_num)" >&2
                    ((errors++))
                fi
                ;;

            "Обоснование весов")
                if [[ "$line" =~ ^([^=]+)=(.+)$ ]]; then
                    local crit="${BASH_REMATCH[1]}"
                    local justification="${BASH_REMATCH[2]}"
                    crit=$(echo "$crit" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    if ! __exists_in_array tmp_criteria "$crit"; then
                        echo "Ошибка: критерий '$crit' не объявлен (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    tmp_justifications["$crit"]="$justification"
                else
                    echo "Ошибка формата обоснования: '$line' (строка $line_num)" >&2
                    ((errors++))
                fi
                ;;

            "Параметры")
                if [[ "$line" =~ ^([^=]+)=(.+)$ ]]; then
                    local param="${BASH_REMATCH[1]}"
                    local value="${BASH_REMATCH[2]}"
                    param=$(echo "$param" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    case "$param" in
                        "СОГЛАСОВАННОСТЬ_ПОРОГ"|"согласованность_порог")
                            if [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                                if bc_compare "$value" "0" "ge" && bc_compare "$value" "1" "le"; then
                                    tmp_consistency_threshold="$value"
                                else
                                    echo "Ошибка: порог согласованности вне диапазона 0-1: $value (строка $line_num)" >&2
                                    ((errors++))
                                fi
                            else
                                echo "Ошибка: некорректное значение порога: $value (строка $line_num)" >&2
                                ((errors++))
                            fi
                            ;;
                        "АГРЕГАЦИЯ_МЕТОД"|"агрегация_метод")
                            if [[ "$value" =~ ^(среднее|медиана|геом_среднее)$ ]]; then
                                tmp_aggregation_method="$value"
                            else
                                echo "Ошибка: неизвестный метод агрегации: $value (строка $line_num)" >&2
                                ((errors++))
                            fi
                            ;;
                        "МИНИМАЛЬНЫЙ_РАНГ"|"минимальный_ранг")
                            if [[ "$value" =~ ^[0-9]+$ ]]; then
                                tmp_min_rank="$value"
                            else
                                echo "Ошибка: минимальный ранг должен быть целым числом: $value (строка $line_num)" >&2
                                ((errors++))
                            fi
                            ;;
                        *)
                            echo "Предупреждение: неизвестный параметр: $param (строка $line_num)" >&2
                            ;;
                    esac
                fi
                ;;

            "Оценки экспертов")
                if [[ "$line" =~ ^([^:]+):([^:]+):(.+)$ ]]; then
                    local expert="${BASH_REMATCH[1]}"
                    local alt="${BASH_REMATCH[2]}"
                    local scores_str="${BASH_REMATCH[3]}"

                    expert=$(echo "$expert" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    alt=$(echo "$alt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    # Проверка существования эксперта и альтернативы
                    if ! __exists_in_array tmp_experts "$expert"; then
                        echo "Ошибка: эксперт '$expert' не найден (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    if ! __exists_in_array tmp_alternatives "$alt"; then
                        echo "Ошибка: альтернатива '$alt' не найдена (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    # Разделение оценок
                    IFS=',' read -ra scores <<< "$scores_str"
                    local scores_count=${#scores[@]}
                    local criteria_count=${#tmp_criteria[@]}

                    if [[ $scores_count -ne $criteria_count ]]; then
                        echo "Ошибка: количество оценок ($scores_count) не соответствует количеству критериев ($criteria_count) для $expert:$alt (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    # Запись оценок
                    for ((i=0; i<criteria_count; i++)); do
                        local crit="${tmp_criteria[$i]}"
                        local score="${scores[$i]// /}"

                        # Проверка корректности оценки
                        if [[ ! "$score" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                            echo "Ошибка: некорректная оценка '$score' для $expert:$alt:$crit (строка $line_num)" >&2
                            ((errors++))
                            continue 2
                        fi

                        if bc_compare "$score" "0" "lt" || bc_compare "$score" "10" "gt"; then
                            echo "Ошибка: оценка вне диапазона 0-10: $expert:$alt:$crit=$score (строка $line_num)" >&2
                            ((errors++))
                            continue 2
                        fi

                        tmp_ratings["$expert,$alt,$crit"]="$score"
                    done
                else
                    echo "Ошибка формата оценки: '$line' (строка $line_num)" >&2
                    ((errors++))
                fi
                ;;

            *)
                if [[ -n "$current_section" ]]; then
                    echo "Предупреждение: данные вне известной секции '$current_section' (строка $line_num)" >&2
                fi
                ;;
        esac
    done <<< "$template"

    # Проверка полноты данных
    if [[ ${#tmp_alternatives[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы альтернативы" >&2
        ((errors++))
    fi

    if [[ ${#tmp_experts[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы эксперты" >&2
        ((errors++))
    fi

    if [[ ${#tmp_criteria[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы критерии" >&2
        ((errors++))
    fi

    # Проверка наличия весов для всех критериев
    for crit in "${tmp_criteria[@]}"; do
        if [[ -z "${tmp_weights[$crit]+isset}" ]]; then
            echo "Предупреждение: не задан вес для критерия '$crit'" >&2
        fi
    done

    # Проверка наличия всех оценок
    local expected_count=$((${#tmp_experts[@]} * ${#tmp_alternatives[@]} * ${#tmp_criteria[@]}))
    local actual_count=${#tmp_ratings[@]}
    if [[ $expected_count -ne $actual_count ]]; then
        echo "Ошибка: не хватает оценок (ожидается: $expected_count, найдено: $actual_count)" >&2
        ((errors++))
    fi

    # Применение данных, если нет ошибок
    if [[ $errors -gt 0 ]]; then
        echo "Импорт отменен из-за $errors ошибок" >&2
        return 1
    fi

    # Применение данных
    data_cleanup

    # Копирование данных из временных структур
    ALTERNATIVES=("${tmp_alternatives[@]}")
    EXPERTS=("${tmp_experts[@]}")
    CRITERIA=("${tmp_criteria[@]}")

    for key in "${!tmp_weights[@]}"; do
        CRITERIA_WEIGHTS["$key"]="${tmp_weights[$key]}"
    done

    for key in "${!tmp_justifications[@]}"; do
        CRITERIA_JUSTIFICATION["$key"]="${tmp_justifications[$key]}"
    done

    for key in "${!tmp_ratings[@]}"; do
        RATINGS["$key"]="${tmp_ratings[$key]}"
    done

    # Установка параметров
    CONSISTENCY_THRESHOLD="${tmp_consistency_threshold:-0.65}"
    AGGREGATION_METHOD="${tmp_aggregation_method:-среднее}"
    MIN_RANK="${tmp_min_rank:-1}"
    CURRENT_TEMPLATE="$tmp_template"

    # Нормализация весов
    normalize_weights

    echo "Импорт успешен: ${#ALTERNATIVES[@]} альтернатив, ${#EXPERTS[@]} экспертов, ${#CRITERIA[@]} критериев" >&2
    return 0
}

normalize_weights() {
    [[ ${#CRITERIA[@]} -eq 0 ]] && {
        echo "Ошибка: нет критериев для нормализации весов" >&2
        return 1
    }

    local weight_sum=0 valid_count=0 has_any_positive=0
    declare -A temp_weights

    for crit in "${CRITERIA[@]}"; do
        local weight="${CRITERIA_WEIGHTS[$crit]:-0}"

        # Строгая валидация с обработкой ошибок
        if [[ ! "$weight" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            echo "Ошибка: некорректный формат веса для '$crit': '$weight'" >&2
            echo "  Вес должен быть неотрицательным числом" >&2
            weight=0
        elif bc_compare "$weight" "0" "lt"; then
            echo "Ошибка: отрицательный вес для '$crit': '$weight'" >&2
            weight=0
        fi

        temp_weights["$crit"]="$weight"
        weight_sum=$(bc_calc "$weight_sum + $weight")

        if [[ -n "${CRITERIA_WEIGHTS[$crit]+isset}" ]]; then
            ((valid_count++))
            bc_compare "$weight" "0" "gt" && has_any_positive=1
        fi
    done

    # Случай 1: Нет весов или все нулевые
    if [[ $valid_count -eq 0 ]] || bc_compare "$has_any_positive" "0" "eq"; then
        echo "Внимание: веса не заданы или все равны 0" >&2
        echo "Устанавливается равномерное распределение" >&2

        local equal_weight=$(bc_calc "100 / ${#CRITERIA[@]}")
        for crit in "${CRITERIA[@]}"; do
            CRITERIA_WEIGHTS["$crit"]=$equal_weight
        done
        return 0
    fi

    # Случай 2: Сумма весов слишком мала
    if bc_compare "$weight_sum" "0.01" "le"; then
        echo "Ошибка: сумма весов слишком мала ($weight_sum)" >&2
        echo "Введите корректно суммирующиеся значения весов" >&2
        return 1
    fi

    # Случай 3: Нормализация при необходимости
    local diff=$(bc_calc "abs($weight_sum - 100)")
    if bc_compare "$diff" "0.5" "gt"; then
        echo "Нормализую веса: сумма была $weight_sum%" >&2
        for crit in "${CRITERIA[@]}"; do
            CRITERIA_WEIGHTS["$crit"]=$(bc_calc "${temp_weights[$crit]} * 100 / $weight_sum")
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

    echo "Нормализация завершена. Сумма весов: $(LANG=C printf "%.2f" "$final_sum")%" >&2
    return 0
}

data_edit() {
    local edit_template="${CURRENT_TEMPLATE:-$DEFAULT_TEMPLATE}"
    local temp_file
    temp_file=$(mktemp /tmp/data_edit_XXXXXX 2>/dev/null) || {
        echo "Ошибка создания временного файла" >&2
        return 1
    }

    # Гарантируем удаление файла при выходе
    trap "rm -f '$temp_file' 2>/dev/null" EXIT INT TERM

    # Записываем шаблон во временный файл
    echo "$edit_template" > "$temp_file" || {
        echo "Ошибка записи во временный файл" >&2
        rm -f "$temp_file"
        return 1
    }

    # Получаем отредактированные данные
    local edited_data
    edited_data=$(zenity --text-info \
        --title="Редактирование шаблона данных задачи 4" \
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

    if [[ "$edited_data" == "$edit_template" ]]; then
        zenity --info \
            --title="Данные не изменились" \
            --text="Данные не были изменены." \
            --width=300 2>/dev/null
        return 0
    fi

    if data_import "$edited_data"; then
        zenity --info \
            --title="Данные обновлены" \
            --text="Шаблон успешно импортирован!\n\n• Альтернатив: ${#ALTERNATIVES[@]}\n• Экспертов: ${#EXPERTS[@]}\n• Критериев: ${#CRITERIA[@]}" \
            --width=400 2>/dev/null
        return 0
    else
        zenity --error \
            --title="Ошибка импорта" \
            --text="Не удалось импортировать отредактированный шаблон.\nПроверьте формат данных.\n\nДанные восстановлены из предыдущей версии." \
            --width=500 2>/dev/null
        return 1
    fi
}

data_validate() {
    local errors=0
    local warnings=0

    echo "Валидация данных..." >&2

    # Проверка базовых структур
    if [[ ${#ALTERNATIVES[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы альтернативы" >&2
        errors=1
    else
        echo "  Альтернатив: ${#ALTERNATIVES[@]}" >&2
    fi

    if [[ ${#EXPERTS[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы эксперты" >&2
        errors=1
    else
        echo "  Экспертов: ${#EXPERTS[@]}" >&2
    fi

    if [[ ${#CRITERIA[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы критерии" >&2
        errors=1
    else
        echo "  Критериев: ${#CRITERIA[@]}" >&2
    fi

    # Проверка весов критериев
    local weight_sum=0
    for crit in "${CRITERIA[@]}"; do
        if [[ -z "${CRITERIA_WEIGHTS[$crit]+isset}" ]]; then
            echo "Предупреждение: не задан вес для критерия '$crit'" >&2
            warnings=1
        else
            weight_sum=$(bc_calc "$weight_sum + ${CRITERIA_WEIGHTS[$crit]}")
        fi
    done

    # Проверка обоснований
    for crit in "${CRITERIA[@]}"; do
        if [[ -z "${CRITERIA_JUSTIFICATION[$crit]+isset}" ]]; then
            echo "Предупреждение: не задано обоснование для критерия '$crit'" >&2
            warnings=1
        fi
    done

    # Проверка матрицы оценок
    local expected_count=$((${#EXPERTS[@]} * ${#ALTERNATIVES[@]} * ${#CRITERIA[@]}))
    local actual_count=0
    local missing_count=0

    for expert in "${EXPERTS[@]}"; do
        for alt in "${ALTERNATIVES[@]}"; do
            for crit in "${CRITERIA[@]}"; do
                if [[ -z "${RATINGS[$expert,$alt,$crit]+isset}" ]]; then
                    echo "Ошибка: отсутствует оценка для эксперта '$expert', альтернативы '$alt', критерия '$crit'" >&2
                    missing_count=$((missing_count + 1))
                    errors=1
                else
                    actual_count=$((actual_count + 1))
                    local value="${RATINGS[$expert,$alt,$crit]}"
                    if ! bc_compare "$value" "0" "ge" || ! bc_compare "$value" "10" "le"; then
                        echo "Предупреждение: оценка $expert:$alt:$crit=$value вне диапазона 0-10" >&2
                        warnings=1
                    fi
                fi
            done
        done
    done

    echo "  Ожидалось оценок: $expected_count" >&2
    echo "  Найдено оценок: $actual_count" >&2
    if [[ $missing_count -gt 0 ]]; then
        echo "  Отсутствует оценок: $missing_count" >&2
    fi

    # Проверка суммы весов
    if [[ $errors -eq 0 ]]; then
        local diff=$(bc_calc "abs($weight_sum - 100)")
        if bc_compare "$diff" "0.1" "gt"; then
            echo "Предупреждение: сумма весов ($weight_sum) отличается от 100%" >&2
            warnings=1
        fi
    fi

    if [[ $errors -eq 0 ]]; then
        if [[ $warnings -gt 0 ]]; then
            echo "Валидация пройдена с предупреждениями" >&2
        else
            echo "Валидация пройдена успешно" >&2
        fi
        return 0
    else
        echo "Валидация не пройдена, найдено $errors ошибок и $warnings предупреждений" >&2
        return 1
    fi
}

# === ЗАВИСИМОСИ ===
deps_check() {
    local missing=0

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

    local test_file=$(mktemp -u)
    if ! touch "$test_file" 2>/dev/null; then
        echo "Ошибка: Нет прав на запись во временные файлы!"
        echo "Проверьте права доступа к /tmp"
        exit 1
    fi

    rm -f "$test_file"
}

# === ЗАПУСК ===
deps_check && case " $* " in
  *" calc "*)
      bc_init && \
      data_load_default && \
      (
        subtask1_individual_aggregation
        subtask2_pairwise_comparison
        subtask3_criteria_weights
        subtask4_expert_consistency
        subtask5_rank_dependencies
      )
      ;;
  *) zenity_main_menu ;;
esac
