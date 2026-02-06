#!/bin/bash

# Основные данные
declare -a ALT_NAMES CRITERIA_NAMES
declare -A FUZZY_WEIGHTS FUZZY_RATINGS

# Нечеткая система
declare -A FUZZY_TERMS OUTPUT_TERMS OUTPUT_CENTROIDS
declare -a FUZZY_RULES FUZZY_INPUT_VARS

# Результаты (пронумерованы как подзадачи)
declare -A RESULTS_1 RESULTS_2 RESULTS_3 RESULTS_4
declare -A RANKS_1 RANKS_2 RANKS_3 RANKS_4
declare -A NORMALIZED_1 NORMALIZED_2 NORMALIZED_3 NORMALIZED_4

# Технические переменные
declare PROGRESS_FILE PROGRESS_PID bcsc=6
declare CURRENT_TEMPLATE

DEFAULT_TEMPLATE=$(cat <<'EOF'
# ШАБЛОН ДЛЯ ЗАДАЧИ 9: НЕЧЕТКАЯ ЛОГИКА

[Альтернативы]
UBUNTU, FEDORA, ASTRA_LINUX, ALT_LINUX, CALCULATE_LINUX

[Критерии]
БЕЗОПАСНОСТЬ, СТАБИЛЬНОСТЬ, ДОКУМЕНТАЦИЯ, ПОДДЕРЖКА, СТОИМОСТЬ

[Нечеткие_веса]
# Веса заданы как треугольные нечеткие числа.
# (low, mid, high) в шкале [0,1], отражая небольшую неопределенность вокруг "жестких" весов.
БЕЗОПАСНОСТЬ:0.30,0.35,0.40
СТАБИЛЬНОСТЬ:0.20,0.25,0.30
ДОКУМЕНТАЦИЯ:0.10,0.15,0.20
ПОДДЕРЖКА:0.07,0.10,0.13
СТОИМОСТЬ:0.10,0.15,0.20

[Нечеткие_оценки]
# Формат: АЛЬТЕРНАТИВА:КРИТЕРИЙ:low,mid,high
UBUNTU:БЕЗОПАСНОСТЬ:0.70,0.80,0.90
UBUNTU:СТАБИЛЬНОСТЬ:0.70,0.80,0.90
UBUNTU:ДОКУМЕНТАЦИЯ:0.80,0.90,1.00
UBUNTU:ПОДДЕРЖКА:0.80,0.90,1.00
UBUNTU:СТОИМОСТЬ:0.90,1.00,1.00

FEDORA:БЕЗОПАСНОСТЬ:0.60,0.70,0.80
FEDORA:СТАБИЛЬНОСТЬ:0.20,0.40,0.60
FEDORA:ДОКУМЕНТАЦИЯ:0.50,0.60,0.70
FEDORA:ПОДДЕРЖКА:0.50,0.60,0.70
FEDORA:СТОИМОСТЬ:0.90,1.00,1.00

ASTRA_LINUX:БЕЗОПАСНОСТЬ:0.80,0.90,1.00
ASTRA_LINUX:СТАБИЛЬНОСТЬ:0.70,0.80,0.90
ASTRA_LINUX:ДОКУМЕНТАЦИЯ:0.60,0.70,0.80
ASTRA_LINUX:ПОДДЕРЖКА:0.70,0.80,0.90
ASTRA_LINUX:СТОИМОСТЬ:0.20,0.30,0.40

ALT_LINUX:БЕЗОПАСНОСТЬ:0.80,0.90,1.00
ALT_LINUX:СТАБИЛЬНОСТЬ:0.70,0.80,0.90
ALT_LINUX:ДОКУМЕНТАЦИЯ:0.60,0.70,0.80
ALT_LINUX:ПОДДЕРЖКА:0.60,0.70,0.80
ALT_LINUX:СТОИМОСТЬ:0.80,0.90,1.00

CALCULATE_LINUX:БЕЗОПАСНОСТЬ:0.60,0.70,0.80
CALCULATE_LINUX:СТАБИЛЬНОСТЬ:0.70,0.80,0.90
CALCULATE_LINUX:ДОКУМЕНТАЦИЯ:0.50,0.60,0.70
CALCULATE_LINUX:ПОДДЕРЖКА:0.50,0.60,0.70
CALCULATE_LINUX:СТОИМОСТЬ:0.70,0.80,0.90

[Нечеткая_система]
# Входные лингвистические переменные.
ВХОДНЫЕ.БЕЗОПАСНОСТЬ.низкий=0.0,0.0,0.4
ВХОДНЫЕ.БЕЗОПАСНОСТЬ.средний=0.25,0.5,0.75
ВХОДНЫЕ.БЕЗОПАСНОСТЬ.высокий=0.6,1.0,1.0

ВХОДНЫЕ.СТАБИЛЬНОСТЬ.низкий=0.0,0.0,0.4
ВХОДНЫЕ.СТАБИЛЬНОСТЬ.средний=0.25,0.5,0.75
ВХОДНЫЕ.СТАБИЛЬНОСТЬ.высокий=0.6,1.0,1.0

ВХОДНЫЕ.ДОКУМЕНТАЦИЯ.низкий=0.0,0.0,0.4
ВХОДНЫЕ.ДОКУМЕНТАЦИЯ.средний=0.25,0.5,0.75
ВХОДНЫЕ.ДОКУМЕНТАЦИЯ.высокий=0.6,1.0,1.0

ВХОДНЫЕ.ПОДДЕРЖКА.низкий=0.0,0.0,0.4
ВХОДНЫЕ.ПОДДЕРЖКА.средний=0.25,0.5,0.75
ВХОДНЫЕ.ПОДДЕРЖКА.высокий=0.6,1.0,1.0

# Для СТОИМОСТИ:
#   Оценка в [Нечеткие_оценки] – это "доступность по стоимости" (дешевизна):
#       1 – очень дёшево, 0 – крайне затратно.
ВХОДНЫЕ.СТОИМОСТЬ.низкий=0.6,0.9,1.0
ВХОДНЫЕ.СТОИМОСТЬ.средний=0.3,0.5,0.7
ВХОДНЫЕ.СТОИМОСТЬ.высокий=0.0,0.1,0.4

ВЫХОДНЫЕ.ПРИГОДНОСТЬ.низкая=0.0,0.2,0.4
ВЫХОДНЫЕ.ПРИГОДНОСТЬ.средняя=0.3,0.5,0.7
ВЫХОДНЫЕ.ПРИГОДНОСТЬ.высокая=0.6,0.9,1.0

ПРАВИЛО1=ЕСЛИ БЕЗОПАСНОСТЬ=высокий И СТАБИЛЬНОСТЬ=высокий ТО ПРИГОДНОСТЬ=высокая
ПРАВИЛО2=ЕСЛИ БЕЗОПАСНОСТЬ=высокий И СТАБИЛЬНОСТЬ=средний ТО ПРИГОДНОСТЬ=средняя
ПРАВИЛО3=ЕСЛИ БЕЗОПАСНОСТЬ=средний И СТАБИЛЬНОСТЬ=высокий ТО ПРИГОДНОСТЬ=средняя
ПРАВИЛО4=ЕСЛИ БЕЗОПАСНОСТЬ=низкий ТО ПРИГОДНОСТЬ=низкая
ПРАВИЛО5=ЕСЛИ СТАБИЛЬНОСТЬ=низкий ТО ПРИГОДНОСТЬ=низкая
ПРАВИЛО6=ЕСЛИ СТОИМОСТЬ=высокий И БЕЗОПАСНОСТЬ=высокий ТО ПРИГОДНОСТЬ=средняя
ПРАВИЛО7=ЕСЛИ СТОИМОСТЬ=высокий И СТАБИЛЬНОСТЬ=высокий ТО ПРИГОДНОСТЬ=средняя
ПРАВИЛО8=ЕСЛИ СТОИМОСТЬ=высокий И БЕЗОПАСНОСТЬ=средний ТО ПРИГОДНОСТЬ=низкая
ПРАВИЛО9=ЕСЛИ СТОИМОСТЬ=высокий И СТАБИЛЬНОСТЬ=средний ТО ПРИГОДНОСТЬ=низкая
ПРАВИЛО10=ЕСЛИ ДОКУМЕНТАЦИЯ=высокий И ПОДДЕРЖКА=высокий ТО ПРИГОДНОСТЬ=высокая
ПРАВИЛО11=ЕСЛИ ДОКУМЕНТАЦИЯ=высокий И СТОИМОСТЬ=низкий ТО ПРИГОДНОСТЬ=высокая
ПРАВИЛО12=ЕСЛИ ПОДДЕРЖКА=высокий И СТОИМОСТЬ=низкий ТО ПРИГОДНОСТЬ=высокая
ПРАВИЛО13=ЕСЛИ ДОКУМЕНТАЦИЯ=низкий ТО ПРИГОДНОСТЬ=низкая
ПРАВИЛО14=ЕСЛИ ПОДДЕРЖКА=низкий ТО ПРИГОДНОСТЬ=низкая
EOF
)

# === ИНТЕРФЕЙС ===
zenity_show_conditions() {
    if ! data_validate; then
        zenity --error --title="Ошибка данных" \
            --text="Данные не загружены или повреждены.\nЗагрузите данные заново." --width=500 2>/dev/null
        return
    fi

    local conditions_text="ЗАДАЧА 9: МНОГОКРИТЕРИАЛЬНЫЙ ВЫБОР НА ОСНОВЕ НЕЧЕТКИХ МНОЖЕСТВ

ЦЕЛЬ:
Выбрать оптимальную альтернативу при неопределенности экспертных оценок (нечеткие числа).

ОСНОВНЫЕ ЭТАПЫ:
1. Представление оценок и весов как треугольных нечетких чисел (low, mid, high)
   - Дефаззификация треугольного числа: центр тяжести (CoA) = (low + mid + high) / 3

2. Аддитивная свертка
   - Метод 1: Нечеткие веса критериев × нечеткие оценки → сумма треугольников → дефаззификация результата
   - Метод 2: Дефаззификация весов → нормализация (Σ=1) → четкая взвешенная сумма (по центроидам оценок)

3. Нечеткая система вывода (Мамдани, упрощенная)
   - Фаззификация четких значений критериев по лингвистическим термам (треугольные функции принадлежности)
   - Правила IF-THEN с операторами И/ИЛИ: И → min, ИЛИ → max
   - Агрегация по выходным термам: max по активированным правилам
   - Дефаззификация: взвешенное среднее по центрам выходных термов

ДАННЫЕ:
• Альтернатив: ${#ALT_NAMES[@]}
• Критериев: ${#CRITERIA_NAMES[@]}
• Правил нечеткой системы: ${#FUZZY_RULES[@]}
• Нечетких весов: ${#FUZZY_WEIGHTS[@]}/12
• Лингвтермов: ${#FUZZY_TERMS[@]}"

    echo "$conditions_text" | zenity --text-info --title="Задача 9" \
        --width=800 --height=700 --font="monospace 10" 2>/dev/null || true
}

zenity_main_menu() {
    bc_init

    if ! data_load_default; then
        zenity --error \
            --title="Критическая ошибка" \
            --text="Не удалось загрузить данные по умолчанию." \
            --width=400 2>/dev/null
        return 1
    fi

    while true; do
        local choice=$(zenity --list \
            --title="Задача 9: Нечеткие множества" \
            --text="Действие:" \
            --column="Опция" \
            "▶ Выполнить все задачи" \
            "1. Аддитивная свертка с нечеткими весами" \
            "2. Аддитивная свертка с нормализованными весами" \
            "3. Сравнительный анализ методов" \
            "4. Нечеткая система вывода" \
            "✏️ Редактировать данные" \
            "📋 Условия задачи" \
            --width=450 --height=500 2>/dev/null)

        case "$choice" in
            "▶ Выполнить все задачи") zenity_run_all_tasks ;;
            "1. Аддитивная свертка с нечеткими весами")
                { subtask1_fuzzy_weights; } | zenity --text-info \
                    --title="Задача 1" \
                    --width=800 --height=850 --font="monospace 10" 2>/dev/null || subtask1_fuzzy_weights ;;
            "2. Аддитивная свертка с нормализованными весами")
                { subtask2_normalized_weights; } | zenity --text-info \
                    --title="Задача 2" \
                    --width=750 --height=600 --font="monospace 10" 2>/dev/null || subtask2_normalized_weights ;;
            "3. Сравнительный анализ методов")
                { subtask3_comparison; } | zenity --text-info \
                    --title="Задача 3" \
                    --width=600 --height=550 --font="monospace 10" 2>/dev/null || subtask3_comparison ;;
            "4. Нечеткая система вывода")
                { subtask4_fuzzy_inference; } | zenity --text-info \
                    --title="Задача 4" \
                    --width=700 --height=800 --font="monospace 10" 2>/dev/null || subtask4_fuzzy_inference ;;
            "✏️ Редактировать данные") data_edit ;;
            "📋 Условия задачи") zenity_show_conditions ;;
            *) break ;;
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

    zenity_progress_start "Решение задачи 9" "Подготовка данных..."

    {
        echo "=== РЕШЕНИЕ ЗАДАЧИ 9: НЕЧЕТКИЕ МНОЖЕСТВА ==="
        echo ""

        echo "25" >&3
        echo "# 1. Аддитивная свертка с нечеткими весами..." >&3
        subtask1_fuzzy_weights

        echo "50" >&3
        echo "# 2. Аддитивная свертка с нормализованными весами..." >&3
        subtask2_normalized_weights

        echo "75" >&3
        echo "# 3. Сравнительный анализ методов..." >&3
        subtask3_comparison

        echo "90" >&3
        echo "# 4. Нечеткая система вывода..." >&3
        subtask4_fuzzy_inference

        echo "100" >&3
        echo "# Вычисления завершены" >&3
        sleep 0.5

    } > "$temp_file" 2>&1

    zenity_progress_stop

    cat "$temp_file" | zenity --text-info \
        --title="Решение задачи 9" \
        --width=850 --height=900 \
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

# === ПОДЗАДАЧИ  ===
subtask1_fuzzy_weights() {
    echo "ЗАДАЧА 9.1: АДДИТИВНАЯ СВЕРТКА С НЕЧЕТКИМИ ВЕСАМИ"
    echo "================================================="
    echo ""
    echo "МЕТОД: Взвешенная сумма треугольных нечетких чисел"
    echo "ФОРМУЛА: Σ (wⱼ ⊗ rᵢⱼ), wⱼ и rᵢⱼ – треугольные числа (low,mid,high)"
    echo ""

    # Фикс ALT_NAMES / ALTNAMES
    local -a ALTS=( "${ALT_NAMES[@]}" )
    [[ ${#ALTS[@]} -eq 0 && ${#ALTNAMES[@]} -gt 0 ]] && ALTS=( "${ALTNAMES[@]}" )

    local -a CRITS=( "${CRITERIA_NAMES[@]}" )
    [[ ${#CRITS[@]} -eq 0 && ${#CRITERIANAMES[@]} -gt 0 ]] && CRITS=( "${CRITERIANAMES[@]}" )

    unset RESULTS_1 2>/dev/null; declare -gA RESULTS_1
    unset RANKS_1   2>/dev/null; declare -gA RANKS_1

    # Если нечеткие веса не заданы – используем равные
    if [ ${#FUZZY_WEIGHTS[@]} -eq 0 ]; then
        echo "ОШИБКА: Не заданы нечеткие веса критериев; используются равные веса."
        for crit in "${CRITS[@]}"; do
            FUZZY_WEIGHTS["$crit,low"]=0.5
            FUZZY_WEIGHTS["$crit,mid"]=0.5
            FUZZY_WEIGHTS["$crit,high"]=0.5
        done
    fi

    echo "НЕЧЕТКИЕ ВЕСА КРИТЕРИЕВ:"
    echo "------------------------"
    for crit in "${CRITS[@]}"; do
        local w_low="${FUZZY_WEIGHTS[$crit,low]:-0.5}"
        local w_mid="${FUZZY_WEIGHTS[$crit,mid]:-0.5}"
        local w_high="${FUZZY_WEIGHTS[$crit,high]:-0.5}"

        if bc_compare "$w_low" "$w_mid" "gt"; then w_mid="$w_low"; fi
        if bc_compare "$w_mid" "$w_high" "gt"; then w_high="$w_mid"; fi

        LC_NUMERIC=C printf "  %-15s: (%0.3f, %0.3f, %0.3f)\n" \
            "$crit" "$w_low" "$w_mid" "$w_high"
    done
    echo ""

    echo "ВЫЧИСЛЕНИЕ НЕЧЕТКИХ СУММ:"
    echo "-------------------------"
    echo ""

    for alt in "${ALTS[@]}"; do
        echo "Альтернатива: $alt"

        local sum_low=0 sum_mid=0 sum_high=0
        local has_errors=0

        for crit in "${CRITS[@]}"; do
            local w_low="${FUZZY_WEIGHTS[$crit,low]:-0.5}"
            local w_mid="${FUZZY_WEIGHTS[$crit,mid]:-0.5}"
            local w_high="${FUZZY_WEIGHTS[$crit,high]:-0.5}"

            local r_low="${FUZZY_RATINGS[$alt,$crit,low]}"
            local r_mid="${FUZZY_RATINGS[$alt,$crit,mid]}"
            local r_high="${FUZZY_RATINGS[$alt,$crit,high]}"

            if [[ -z "$r_low" || -z "$r_mid" || -z "$r_high" ]]; then
                echo "  Ошибка: отсутствуют оценки для '$crit', критерий пропущен."
                ((has_errors++))
                continue
            fi

            if bc_compare "$r_low" "$r_mid" "gt" || bc_compare "$r_mid" "$r_high" "gt"; then
                echo "  Ошибка: некорректная треугольная оценка по '$crit'."
                ((has_errors++))
                continue
            fi

            local prod_low prod_mid prod_high
            prod_low=$(bc_calc "$w_low * $r_low")
            prod_mid=$(bc_calc "$w_mid * $r_mid")
            prod_high=$(bc_calc "$w_high * $r_high")

            sum_low=$(bc_calc "$sum_low + $prod_low")
            sum_mid=$(bc_calc "$sum_mid + $prod_mid")
            sum_high=$(bc_calc "$sum_high + $prod_high")

            LC_NUMERIC=C printf "  %-12s: (%0.3f,%0.3f,%0.3f) × (%0.3f,%0.3f,%0.3f) = (%0.4f,%0.4f,%0.4f)\n" \
                "$crit" "$w_low" "$w_mid" "$w_high" \
                "$r_low" "$r_mid" "$r_high" \
                "$prod_low" "$prod_mid" "$prod_high"
        done

        if [ $has_errors -gt 0 ]; then
            echo "  Внимание: пропущено $has_errors критериев из-за ошибок."
        fi

        if bc_compare "$sum_low" "$sum_mid" "gt" || bc_compare "$sum_mid" "$sum_high" "gt"; then
            local t_low="$sum_low" t_mid="$sum_mid" t_high="$sum_high"
            sum_low=$(bc_calc "min($t_low, min($t_mid, $t_high))")
            sum_high=$(bc_calc "max($t_low, max($t_mid, $t_high))")
            sum_mid=$(bc_calc "$t_low + $t_mid + $t_high - $sum_low - $sum_high")
        fi

        local centroid
        centroid=$(__triangle_centroid "$sum_low" "$sum_mid" "$sum_high")
        RESULTS_1["$alt"]="$centroid"

        LC_NUMERIC=C printf "  Сумма: (%0.4f, %0.4f, %0.4f) → Центр тяжести: %0.4f\n\n" \
            "$sum_low" "$sum_mid" "$sum_high" "$centroid"
    done

    __calculate_ranks RESULTS_1 RANKS_1

    local -a rows=()
    for alt in "${ALTS[@]}"; do
        rows+=( "$alt|${RESULTS_1[$alt]:-0}|${RANKS_1[$alt]:-0}" )
    done

    __print_table_3 \
        "Результаты метода 1 (нечеткие веса):" \
        "Альтернатива" "Оценка" "Ранг" \
        "%0.4f" "%0.1f" \
        "${rows[@]}"
}

subtask2_normalized_weights() {
    echo "ЗАДАЧА 9.2: АДДИТИВНАЯ СВЕРТКА С НОРМАЛИЗОВАННЫМИ ВЕСАМИ"
    echo "======================================================="
    echo ""
    echo "Шаги: 1) дефаззификация нечетких весов; 2) нормализация; 3) взвешенная сумма."
    echo ""

    local -a ALTS=( "${ALT_NAMES[@]}" )
    [[ ${#ALTS[@]} -eq 0 && ${#ALTNAMES[@]} -gt 0 ]] && ALTS=( "${ALTNAMES[@]}" )

    local -a CRITS=( "${CRITERIA_NAMES[@]}" )
    [[ ${#CRITS[@]} -eq 0 && ${#CRITERIANAMES[@]} -gt 0 ]] && CRITS=( "${CRITERIANAMES[@]}" )

    unset RESULTS_2 2>/dev/null; declare -gA RESULTS_2
    unset RANKS_2   2>/dev/null; declare -gA RANKS_2

    declare -A crisp_weights
    local total=0

    for crit in "${CRITS[@]}"; do
        local w_low="${FUZZY_WEIGHTS[$crit,low]}"
        local w_mid="${FUZZY_WEIGHTS[$crit,mid]}"
        local w_high="${FUZZY_WEIGHTS[$crit,high]}"

        crisp_weights["$crit"]=$(__triangle_centroid "$w_low" "$w_mid" "$w_high")
        total=$(bc_calc "$total + ${crisp_weights[$crit]}")
    done

    if bc_compare "$total" "0" "le"; then
        echo "ОШИБКА: сумма весов равна 0, нормализация невозможна."
        return 1
    fi

    echo "НОРМАЛИЗОВАННЫЕ ВЕСА:"
    for crit in "${CRITS[@]}"; do
        crisp_weights["$crit"]=$(bc_calc "${crisp_weights[$crit]} / $total")
        LC_NUMERIC=C printf "  %-15s: %0.4f\n" "$crit" "${crisp_weights[$crit]}"
    done
    echo ""

    echo "ОЦЕНКИ АЛЬТЕРНАТИВ (взвешенная сумма центроидов):"
    for alt in "${ALTS[@]}"; do
        local score=0
        for crit in "${CRITS[@]}"; do
            local r_low="${FUZZY_RATINGS[$alt,$crit,low]}"
            local r_mid="${FUZZY_RATINGS[$alt,$crit,mid]}"
            local r_high="${FUZZY_RATINGS[$alt,$crit,high]}"

            local rating
            rating=$(__triangle_centroid "$r_low" "$r_mid" "$r_high")
            score=$(bc_calc "$score + $rating * ${crisp_weights[$crit]}")
        done
        RESULTS_2["$alt"]="$score"
        LC_NUMERIC=C printf "  %-12s: %0.4f\n" "$alt" "$score"
    done
    echo ""

    __calculate_ranks RESULTS_2 RANKS_2

    local -a rows=()
    for alt in "${ALTS[@]}"; do
        rows+=( "$alt|${RESULTS_2[$alt]:-0}|${RANKS_2[$alt]:-0}" )
    done

    __print_table_3 \
        "Результаты метода 2 (норм. веса):" \
        "Альтернатива" "Оценка" "Ранг" \
        "%0.4f" "%0.1f" \
        "${rows[@]}"
}

subtask3_comparison() {
    echo "ЗАДАЧА 9.3: СРАВНИТЕЛЬНЫЙ АНАЛИЗ МЕТОДОВ"
    echo "======================================"
    echo ""

    local -a ALTS=( "${ALT_NAMES[@]}" )
    [[ ${#ALTS[@]} -eq 0 && ${#ALTNAMES[@]} -gt 0 ]] && ALTS=( "${ALTNAMES[@]}" )

    [ ${#RESULTS_1[@]} -eq 0 ] && subtask1_fuzzy_weights >/dev/null 2>&1
    [ ${#RESULTS_2[@]} -eq 0 ] && subtask2_normalized_weights >/dev/null 2>&1

    echo "СРАВНЕНИЕ ОЦЕНОК:"
    local -a rows=()

    for alt in "${ALTS[@]}"; do
        local d
        d=$(bc_calc "${RESULTS_1[$alt]} - ${RESULTS_2[$alt]}")
        if bc_compare "$d" "0" "lt"; then d=$(bc_calc "-1 * ($d)"); fi
        rows+=( "$alt|${RESULTS_1[$alt]}|${RESULTS_2[$alt]}|$d" )
    done

    # Заголовок без символов "|" (иначе ломает визуальные разделители)
    __print_table_4 \
        "" \
        "Альтернатива" "Метод 1" "Метод 2" "Δ" \
        "%0.4f" "%0.4f" "%0.4f" \
        "${rows[@]}"

    echo ""
    echo "СРАВНЕНИЕ РАНГОВ:"
    local -a rrows=()

    for alt in "${ALTS[@]}"; do
        local rank1="${RANKS_1[$alt]:-0}"
        local rank2="${RANKS_2[$alt]:-0}"
        local status="OK"
        [[ "$rank1" != "$rank2" ]] && status="DIFF"
        rrows+=( "$alt|$rank1|$rank2|$status" )
    done

    __print_table_4 \
        "" \
        "Альтернатива" "Ранг 1" "Ранг 2" "Статус" \
        "%s" "%s" "%s" \
        "${rrows[@]}"

    echo ""
}

subtask4_fuzzy_inference() {
    echo "ЗАДАЧА 9.4: НЕЧЕТКАЯ СИСТЕМА ВЫВОДА МАМДАНИ (ДИНАМИЧЕСКАЯ)"
    echo "=========================================================="
    echo ""

    local -a ALTS=( "${ALT_NAMES[@]}" )
    [[ ${#ALTS[@]} -eq 0 && ${#ALTNAMES[@]} -gt 0 ]] && ALTS=( "${ALTNAMES[@]}" )

    if [ ${#FUZZY_RULES[@]} -eq 0 ]; then
        echo "ОШИБКА: не загружены правила нечеткой системы."
        return 1
    fi

    echo "КОНФИГУРАЦИЯ СИСТЕМЫ:"
    echo "  Правил загружено: ${#FUZZY_RULES[@]}"

    declare -A input_criteria
    for rule in "${FUZZY_RULES[@]}"; do
        if [[ "$rule" =~ ([A-ZА-Я_]+)= ]]; then
            input_criteria["${BASH_REMATCH[1]}"]=1
        fi
    done

    echo "  Входные критерии: ${!input_criteria[*]}"
    echo "  Выходная переменная: ПРИГОДНОСТЬ"
    echo ""

    unset RESULTS_4 2>/dev/null; declare -gA RESULTS_4
    unset RANKS_4   2>/dev/null; declare -gA RANKS_4

    echo "ЦЕНТРЫ ТЯЖЕСТИ ВЫХОДНЫХ ТЕРМОВ:"
    declare -A output_centroids

    for term_key in "${!OUTPUT_TERMS[@]}"; do
        if [[ "$term_key" =~ ^([^,]+),low$ ]]; then
            local term="${BASH_REMATCH[1]}"
            local low="${OUTPUT_TERMS[$term,low]}"
            local mid="${OUTPUT_TERMS[$term,mid]}"
            local high="${OUTPUT_TERMS[$term,high]}"

            if [[ -n "$low" && -n "$mid" && -n "$high" ]]; then
                output_centroids["$term"]=$(__triangle_centroid "$low" "$mid" "$high")
                LC_NUMERIC=C printf "  %-10s: (%0.3f, %0.3f, %0.3f) → %0.4f\n" \
                    "$term" "$low" "$mid" "$high" "${output_centroids[$term]}"
            fi
        fi
    done

    if [ ${#output_centroids[@]} -eq 0 ]; then
        echo "ОШИБКА: не определены выходные термы." >&2
        return 1
    fi
    echo ""

    declare -a parsed_rules
    local rule_errors=0

    echo "ПАРСИНГ ПРАВИЛ:"
    echo "--------------"
    for i in "${!FUZZY_RULES[@]}"; do
        local rule_text="${FUZZY_RULES[$i]}"
        local parsed
        parsed=$(__parse_fuzzy_rule "$rule_text")
        if [ -n "$parsed" ]; then
            parsed_rules+=("$parsed")
            echo "  Правило $((i+1)): OK"
        else
            echo "  Правило $((i+1)): ERR: '$rule_text'"
            ((rule_errors++))
        fi
    done

    if [ ${#parsed_rules[@]} -eq 0 ]; then
        echo "ОШИБКА: нет корректных правил для обработки." >&2
        return 1
    fi
    if [ $rule_errors -gt 0 ]; then
        echo "  Предупреждение: $rule_errors правил(а) будут пропущены."
    fi
    echo ""

    for alt in "${ALTS[@]}"; do
        echo "-------------------------------------------------------"
        echo "АНАЛИЗ АЛЬТЕРНАТИВЫ: $alt"
        echo ""

        unset crisp_values membership_values rule_strengths rule_outputs term_strength 2>/dev/null
        declare -A crisp_values membership_values rule_strengths rule_outputs term_strength

        echo "ЧЕТКИЕ ЗНАЧЕНИЯ КРИТЕРИЕВ:"
        for criterion in "${!input_criteria[@]}"; do
            local low="${FUZZY_RATINGS[$alt,$criterion,low]}"
            local mid="${FUZZY_RATINGS[$alt,$criterion,mid]}"
            local high="${FUZZY_RATINGS[$alt,$criterion,high]}"

            if [[ -n "$low" && -n "$mid" && -n "$high" ]]; then
                crisp_values["$criterion"]=$(__triangle_centroid "$low" "$mid" "$high")
                LC_NUMERIC=C printf "  %-15s: (%0.3f, %0.3f, %0.3f) → %0.4f\n" \
                    "$criterion" "$low" "$mid" "$high" "${crisp_values[$criterion]}"
            else
                echo "  Внимание: нет оценок для '$criterion', используется 0."
                crisp_values["$criterion"]=0
            fi
        done
        echo ""

        echo "ФАЗЗИФИКАЦИЯ (степени принадлежности):"
        local total_memberships=0

        for criterion in "${!input_criteria[@]}"; do
            local crisp_value="${crisp_values[$criterion]}"
            for term_key in "${!FUZZY_TERMS[@]}"; do
                if [[ "$term_key" =~ ^$criterion,([^,]+),low$ ]]; then
                    local term="${BASH_REMATCH[1]}"
                    local low="${FUZZY_TERMS[$criterion,$term,low]}"
                    local mid="${FUZZY_TERMS[$criterion,$term,mid]}"
                    local high="${FUZZY_TERMS[$criterion,$term,high]}"

                    if [[ -n "$low" && -n "$mid" && -n "$high" ]]; then
                        local membership
                        membership=$(__triangle_membership "$crisp_value" "$low" "$mid" "$high")
                        membership_values["$criterion,$term"]="$membership"

                        if bc_compare "$membership" "0.001" "gt"; then
                            LC_NUMERIC=C printf "  %-15s.%-10s: μ = %0.4f\n" "$criterion" "$term" "$membership"
                            ((total_memberships++))
                        fi
                    fi
                fi
            done
        done

        if [ $total_memberships -eq 0 ]; then
            echo "  Предупреждение: все степени принадлежности равны 0 (проверьте функции принадлежности)."
        fi
        echo ""

        echo "ПРИМЕНЕНИЕ ПРАВИЛ:"
        local activated_rules=0

        for i in "${!parsed_rules[@]}"; do
            local rule_data="${parsed_rules[$i]}"
            local evaluation
            evaluation=$(__evaluate_fuzzy_rule "$rule_data" membership_values)
            local strength output_term
            IFS=':' read -r strength output_term <<< "$evaluation"

            if bc_compare "$strength" "0.001" "gt"; then
                rule_strengths[$((i+1))]="$strength"
                rule_outputs[$((i+1))]="$output_term"
                ((activated_rules++))
                LC_NUMERIC=C printf "  Правило %d: сила = %0.4f, вывод = %s\n" \
                    "$((i+1))" "$strength" "$output_term"
            fi
        done

        if [ $activated_rules -eq 0 ]; then
            echo "  Ни одно правило не активировалось (все силы = 0)."
        fi
        echo ""

        local activated_terms=0
        for rule_num in "${!rule_strengths[@]}"; do
            local s="${rule_strengths[$rule_num]}"
            local t="${rule_outputs[$rule_num]}"
            local cur="${term_strength[$t]:-0}"
            if bc_compare "$s" "$cur" "gt"; then
                term_strength["$t"]="$s"
            fi
        done

        for t in "${!term_strength[@]}"; do
            if bc_compare "${term_strength[$t]}" "0.001" "gt"; then
                ((activated_terms++))
            fi
        done

        echo "АГРЕГАЦИЯ ПО ТЕРМАМ (max по правилам):"
        if [ $activated_terms -eq 0 ]; then
            echo "  Нет активированных термов."
        else
            for t in "${!term_strength[@]}"; do
                if bc_compare "${term_strength[$t]}" "0.001" "gt"; then
                    LC_NUMERIC=C printf "  Терма %-10s: сила = %0.4f\n" "$t" "${term_strength[$t]}"
                fi
            done
        fi
        echo ""

        echo "ДЕФАЗЗИФИКАЦИЯ (взвешенная по центрам термов):"
        local numerator=0
        local denominator=0

        for t in "${!term_strength[@]}"; do
            local strength="${term_strength[$t]}"
            if ! bc_compare "$strength" "0.001" "gt"; then
                continue
            fi

            local centroid="${output_centroids[$t]}"
            if [[ -n "$centroid" ]]; then
                local contribution
                contribution=$(bc_calc "$strength * $centroid")
                numerator=$(bc_calc "$numerator + $contribution")
                denominator=$(bc_calc "$denominator + $strength")

                LC_NUMERIC=C printf "  Терма %-10s: %0.4f × %0.4f = %0.6f\n" \
                    "$t" "$strength" "$centroid" "$contribution"
            fi
        done

        echo ""
        echo "  Итоговые суммы:"
        echo "    Числитель:      $(LC_NUMERIC=C printf "%0.6f" "$numerator")"
        echo "    Знаменатель:    $(LC_NUMERIC=C printf "%0.6f" "$denominator")"
        echo "    Активировано правил: $activated_rules"
        echo "    Активировано термов: $activated_terms"

        local final_score=0
        if bc_compare "$denominator" "0.001" "gt"; then
            final_score=$(bc_calc "$numerator / $denominator")
            if bc_compare "$final_score" "1" "gt"; then final_score=1; fi
            if bc_compare "$final_score" "0" "lt"; then final_score=0; fi
            LC_NUMERIC=C printf "\nИТОГОВАЯ ОЦЕНКА ДЛЯ '%s': %0.6f\n" "$alt" "$final_score"
        else
            final_score=0.5
            echo ""
            echo "НИ ОДНО ПРАВИЛО НЕ АКТИВИРОВАЛОСЬ."
            LC_NUMERIC=C printf "Используем значение по умолчанию: %0.6f\n" "$final_score"
        fi

        RESULTS_4["$alt"]="$final_score"
        echo ""
    done

    __calculate_ranks RESULTS_4 RANKS_4

    local -a rows=()
    for alt in "${ALTS[@]}"; do
        rows+=( "$alt|${RESULTS_4[$alt]:-0}|${RANKS_4[$alt]:-0}" )
    done

    __print_table_3 \
        "ИТОГОВЫЕ РЕЗУЛЬТАТЫ НЕЧЕТКОЙ СИСТЕМЫ:" \
        "Альтернатива" "Оценка" "Ранг" \
        "%0.6f" "%0.1f" \
        "${rows[@]}"

    echo ""
    echo "РЕКОМЕНДАЦИИ:"
    local best_score=0
    declare -a best_alts

    for alt in "${ALTS[@]}"; do
        local score="${RESULTS_4[$alt]}"
        if bc_compare "$score" "$best_score" "gt"; then
            best_score="$score"
            best_alts=("$alt")
        elif bc_compare "$score" "$best_score" "eq"; then
            best_alts+=("$alt")
        fi
    done

    if [ ${#best_alts[@]} -eq 1 ]; then
        LC_NUMERIC=C printf "  Наилучшая альтернатива: '%s' (оценка: %.4f)\n" \
            "${best_alts[0]}" "$best_score"
    else
        echo "  Требуется дополнительный критерий для выбора."
    fi
    echo ""
}

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
__triangle_centroid() {
    local a="$1" b="$2" c="$3"

    # Нормализация десятичного разделителя
    a="${a//,/\.}"
    b="${b//,/\.}"
    c="${c//,/\.}"

    # Проверка на число (разрешаем целые/дробные, с опциональным минусом)
    if ! [[ "$a" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || \
       ! [[ "$b" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || \
       ! [[ "$c" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        echo "0"
        return 1
    fi

    # Центроид треугольного числа (a,b,c) = (a+b+c)/3
    local result
    result=$(LC_NUMERIC=C awk -v a="$a" -v b="$b" -v c="$c" 'BEGIN { printf "%.6f", (a + b + c) / 3 }' 2>/dev/null)

    if [[ -z "$result" || "$result" == "nan" || "$result" == "inf" ]]; then
        echo "0"
        return 1
    fi

    # Убираем хвостовые нули и точку
    result=$(echo "$result" | sed -E 's/0+$//; s/[.]$//')
    [[ -z "$result" ]] && result="0"

    echo "$result"
}

__triangle_membership() {
    local x="$1" low="$2" mid="$3" high="$4"

    # Замена запятых на точки
    x=$(echo "$x"    | tr ',' '.')
    low=$(echo "$low"  | tr ',' '.')
    mid=$(echo "$mid"  | tr ',' '.')
    high=$(echo "$high" | tr ',' '.')

    # Проверяем, что все аргументы – числа
    if ! [[ "$x" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || \
       ! [[ "$low" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || \
       ! [[ "$mid" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || \
       ! [[ "$high" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        echo "0"
        return 1
    fi

    # Вырожденный треугольник: low = mid = high
    if [ "$(echo "$low == $mid && $mid == $high" | bc -l 2>/dev/null)" = "1" ]; then
        if [ "$(echo "$x == $mid" | bc -l 2>/dev/null)" = "1" ]; then
            echo "1"
        else
            echo "0"
        fi
        return 0
    fi

    # x вне [low, high]
    if [ "$(echo "$x < $low" | bc -l 2>/dev/null)" = "1" ] || \
       [ "$(echo "$x > $high" | bc -l 2>/dev/null)" = "1" ]; then
        echo "0"
        return 0
    fi

    local result=0

    if [ "$(echo "$x <= $mid" | bc -l 2>/dev/null)" = "1" ]; then
        # Восходящая ветвь
        if [ "$(echo "$mid == $low" | bc -l 2>/dev/null)" = "1" ]; then
            # Вертикальный левый край
            if [ "$(echo "$x == $low" | bc -l 2>/dev/null)" = "1" ]; then
                result=1
            else
                result=0
            fi
        else
            result=$(echo "($x - $low) / ($mid - $low)" | bc -l 2>/dev/null)
        fi
    else
        # Нисходящая ветвь
        if [ "$(echo "$high == $mid" | bc -l 2>/dev/null)" = "1" ]; then
            # Вертикальный правый край
            if [ "$(echo "$x == $mid" | bc -l 2>/dev/null)" = "1" ]; then
                result=1
            else
                result=0
            fi
        else
            result=$(echo "($high - $x) / ($high - $mid)" | bc -l 2>/dev/null)
        fi
    fi

    # Ограничиваем результат [0,1]
    if [ -z "$result" ] || [ "$result" = "nan" ] || [ "$result" = "inf" ]; then
        result=0
    fi

    if [ "$(echo "$result < 0" | bc -l 2>/dev/null)" = "1" ]; then
        result=0
    elif [ "$(echo "$result > 1" | bc -l 2>/dev/null)" = "1" ]; then
        result=1
    fi

    LANG=C printf "%.6f\n" "$result" 2>/dev/null || echo "0"
}

__parse_fuzzy_rule() {
    local rule_text="$1"
    rule_text=$(echo "$rule_text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    rule_text=$(echo "$rule_text" | sed -E 's/^ПРАВИЛО[0-9]*=//')

    if [[ ! "$rule_text" =~ ^ЕСЛИ[[:space:]].+ТО[[:space:]] ]]; then
        echo "" ; return 1
    fi

    local condition_part="${rule_text#ЕСЛИ }"
    condition_part="${condition_part% ТО *}"
    local conclusion_part="${rule_text#*ТО }"

    if [[ ! "$conclusion_part" =~ ^([^=]+)=(.+)$ ]]; then
        echo "" ; return 1
    fi

    local operator="И"
    if [[ "$condition_part" == *" ИЛИ "* ]]; then
        operator="ИЛИ"
    fi

    local normalized="$condition_part"
    if [ "$operator" = "ИЛИ" ]; then
        normalized="${normalized//" ИЛИ "/"|"}"
    else
        normalized="${normalized//" И "/"|"}"
    fi

    local -a conditions
    IFS='|' read -r -a conditions <<< "$normalized"

    local output_var="${BASH_REMATCH[1]}"
    local output_term="${BASH_REMATCH[2]}"

    local result=""
    local c
    for c in "${conditions[@]}"; do
        c=$(echo "$c" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        result+="$c|"
    done
    result="${result%|}"
    result+=";$operator;$output_var;$output_term"
    echo "$result"
}

__evaluate_fuzzy_rule() {
    local rule_data="$1"
    local -n mv="$2"  # ассоц. массив membership_values, передаётся по имени

    IFS=';' read -r conditions_str operator output_var output_term <<< "$rule_data"
    IFS='|' read -ra conditions <<< "$conditions_str"

    local rule_strength=0
    if [ "${#conditions[@]}" -eq 0 ]; then
        echo "0:$output_term"
        return 1
    fi

    if [ "$operator" = "И" ]; then
        # t-норма: минимум
        rule_strength=1
        for condition in "${conditions[@]}"; do
            if [[ "$condition" =~ ^([^=]+)=(.+)$ ]]; then
                local criterion="${BASH_REMATCH[1]}"
                local term="${BASH_REMATCH[2]}"
                local key="$criterion,$term"

                if [ -n "${mv[$key]+x}" ]; then
                    local strength="${mv[$key]}"
                    if bc_compare "$strength" "$rule_strength" "lt"; then
                        rule_strength="$strength"
                    fi
                else
                    rule_strength=0
                    break
                fi
            fi
        done
    else
        # s-норма: максимум
        rule_strength=0
        for condition in "${conditions[@]}"; do
            if [[ "$condition" =~ ^([^=]+)=(.+)$ ]]; then
                local criterion="${BASH_REMATCH[1]}"
                local term="${BASH_REMATCH[2]}"
                local key="$criterion,$term"

                if [ -n "${mv[$key]+x}" ]; then
                    local strength="${mv[$key]}"
                    if bc_compare "$strength" "$rule_strength" "gt"; then
                        rule_strength="$strength"
                    fi
                fi
            fi
        done
    fi

    echo "$rule_strength:$output_term"
}

__calculate_ranks() {
    local -n scores=$1
    local -n ranks=$2
    local alts_array_name="${3:-}"

    # 1) Определяем список альтернатив, которые надо ранжировать
    local -a alts=()

    if [[ -n "$alts_array_name" ]]; then
        # Пользователь явно передал имя массива альтернатив
        local -n _alts_ref="$alts_array_name"
        alts=( "${_alts_ref[@]}" )
    elif (( ${#ALT_NAMES[@]} > 0 )); then
        # Канонический список из текущего скрипта
        alts=( "${ALT_NAMES[@]}" )
    else
        # Фолбэк: берём ключи из scores
        local k
        for k in "${!scores[@]}"; do
            alts+=( "$k" )
        done
        # Стабилизируем порядок
        IFS=$'\n' alts=( $(LC_ALL=C printf '%s\n' "${alts[@]}" | sort) )
        unset IFS
    fi

    if (( ${#alts[@]} == 0 )); then
        echo "Ошибка: нет альтернатив для ранжирования" >&2
        return 1
    fi

    # 2) Формируем пары "оценка<TAB>альтернатива" для сортировки
    local -a pairs=()
    local alt raw_score score
    for alt in "${alts[@]}"; do
        raw_score="${scores[$alt]:-0}"

        # Нормализуем до числа через bc_calc (если мусор/пусто -> 0)
        score=$(bc_calc "$raw_score" 10 0)

        pairs+=( "$(printf '%s\t%s' "$score" "$alt")" )
    done

    # 3) Сортируем по убыванию оценок
    local -a sorted_pairs=()
    IFS=$'\n' sorted_pairs=( $(LC_ALL=C printf '%s\n' "${pairs[@]}" | sort -t$'\t' -k1,1nr) )
    unset IFS

    # 4) Присваиваем ранги (средний ранг для одинаковых оценок)
    local i=0
    local rank=1

    while (( i < ${#sorted_pairs[@]} )); do
        local current_score current_alt
        IFS=$'\t' read -r current_score current_alt <<< "${sorted_pairs[$i]}"
        unset IFS

        local j=$i
        while (( (j + 1) < ${#sorted_pairs[@]} )); do
            local next_score next_alt
            IFS=$'\t' read -r next_score next_alt <<< "${sorted_pairs[$((j+1))]}"
            unset IFS

            if ! bc_compare "$current_score" "$next_score" "eq"; then
                break
            fi
            ((j++))
        done

        local group_size=$((j - i + 1))
        local avg_rank
        avg_rank=$(bc_calc "($rank + ($rank + $group_size - 1)) / 2" 6 0)

        local k
        for ((k=i; k<=j; k++)); do
            local s a
            IFS=$'\t' read -r s a <<< "${sorted_pairs[$k]}"
            unset IFS
            ranks["$a"]="$avg_rank"
        done

        rank=$((rank + group_size))
        i=$((j + 1))
    done

    return 0
}

# === ФОРМАТИРОВАНИЕ ТАБЛИЦ ===
__repeat_char() {
    local n="$1" ch="$2"
    printf "%*s" "$n" "" | tr ' ' "$ch"
}

__table_pick_utf8_ctype() {
    local cur="${LC_CTYPE:-${LANG:-}}"
    if [[ "$cur" == *UTF-8* || "$cur" == *utf8* ]]; then
        printf '%s' "$cur"
        return 0
    fi

    if command -v locale >/dev/null 2>&1; then
        locale -a 2>/dev/null | grep -qx 'C\.UTF-8'     && { printf '%s' 'C.UTF-8'; return 0; }
        locale -a 2>/dev/null | grep -qx 'ru_RU\.UTF-8' && { printf '%s' 'ru_RU.UTF-8'; return 0; }
        locale -a 2>/dev/null | grep -qx 'en_US\.UTF-8' && { printf '%s' 'en_US.UTF-8'; return 0; }
    fi

    printf '%s' ""
}

__strlen_u8() {
    local s="$1"
    local ctype
    ctype="$(__table_pick_utf8_ctype)"

    if [[ -n "$ctype" ]]; then
        LC_CTYPE="$ctype" awk -v s="$s" 'BEGIN{print length(s)}'
    else
        # fallback по байтам (хуже для кириллицы, но не падает)
        echo "${#s}"
    fi
}

__pad_right_u8() {
    local str="$1" width="$2"
    local len
    len="$(__strlen_u8 "$str")"
    printf "%s" "$str"
    if (( width > len )); then
        printf "%*s" $((width - len)) ""
    fi
}

__pad_left_u8() {
    local str="$1" width="$2"
    local len
    len="$(__strlen_u8 "$str")"
    if (( width > len )); then
        printf "%*s" $((width - len)) ""
    fi
    printf "%s" "$str"
}

__fmt_cell() {
    # fmt, value -> formatted string (без \n)
    local fmt="$1" val="$2"
    local out
    out=$(LC_NUMERIC=C printf -- "$fmt" "$val" 2>/dev/null)
    out="${out//$'\n'/}"
    printf '%s' "$out"
}

__print_table_3() {
    # args: title, col1, col2, col3, fmt2, fmt3, rows...
    # rows: "c1|c2|c3"
    local title="$1"; shift
    local h1="$1" h2="$2" h3="$3"; shift 3
    local fmt2="$1" fmt3="$2"; shift 2
    local -a rows=( "$@" )

    local w1 w2 w3
    w1="$(__strlen_u8 "$h1")"
    w2="$(__strlen_u8 "$h2")"
    w3="$(__strlen_u8 "$h3")"

    local r c1 c2 c3

    # считаем ширины по данным (в символах, после форматирования)
    for r in "${rows[@]}"; do
        IFS='|' read -r c1 c2 c3 <<< "$r"

        local f1 f2 f3
        f1="$(__fmt_cell "%s" "$c1")"
        f2="$(__fmt_cell "$fmt2" "$c2")"
        f3="$(__fmt_cell "$fmt3" "$c3")"

        local l1 l2 l3
        l1="$(__strlen_u8 "$f1")"
        l2="$(__strlen_u8 "$f2")"
        l3="$(__strlen_u8 "$f3")"

        (( l1 > w1 )) && w1=$l1
        (( l2 > w2 )) && w2=$l2
        (( l3 > w3 )) && w3=$l3
    done

    echo "$title"
    __pad_right_u8 "$h1" "$w1"; printf " | "; __pad_left_u8 "$h2" "$w2"; printf " | "; __pad_left_u8 "$h3" "$w3"
    echo ""

    printf "%s" "$(__repeat_char "$w1" '-')"
    printf -- "-+-%s" "$(__repeat_char "$w2" '-')"
    printf -- "-+-%s" "$(__repeat_char "$w3" '-')"
    echo ""

    for r in "${rows[@]}"; do
        IFS='|' read -r c1 c2 c3 <<< "$r"
        local f2 f3
        f2="$(__fmt_cell "$fmt2" "$c2")"
        f3="$(__fmt_cell "$fmt3" "$c3")"

        __pad_right_u8 "$c1" "$w1"; printf " | "; __pad_left_u8 "$f2" "$w2"; printf " | "; __pad_left_u8 "$f3" "$w3"
        echo ""
    done
    echo ""
}

__print_table_4() {
    # args: title, h1 h2 h3 h4, fmt2 fmt3 fmt4, rows "c1|c2|c3|c4"
    local title="$1"; shift
    local h1="$1" h2="$2" h3="$3" h4="$4"; shift 4
    local fmt2="$1" fmt3="$2" fmt4="$3"; shift 3
    local -a rows=( "$@" )

    local w1 w2 w3 w4
    w1="$(__strlen_u8 "$h1")"
    w2="$(__strlen_u8 "$h2")"
    w3="$(__strlen_u8 "$h3")"
    w4="$(__strlen_u8 "$h4")"

    local r c1 c2 c3 c4

    for r in "${rows[@]}"; do
        IFS='|' read -r c1 c2 c3 c4 <<< "$r"

        local f1 f2 f3 f4
        f1="$(__fmt_cell "%s" "$c1")"
        f2="$(__fmt_cell "$fmt2" "$c2")"
        f3="$(__fmt_cell "$fmt3" "$c3")"
        f4="$(__fmt_cell "$fmt4" "$c4")"

        local l1 l2 l3 l4
        l1="$(__strlen_u8 "$f1")"
        l2="$(__strlen_u8 "$f2")"
        l3="$(__strlen_u8 "$f3")"
        l4="$(__strlen_u8 "$f4")"

        (( l1 > w1 )) && w1=$l1
        (( l2 > w2 )) && w2=$l2
        (( l3 > w3 )) && w3=$l3
        (( l4 > w4 )) && w4=$l4
    done

    echo "$title"
    __pad_right_u8 "$h1" "$w1"; printf " | "; __pad_left_u8 "$h2" "$w2"; printf " | "; __pad_left_u8 "$h3" "$w3"; printf " | "; __pad_left_u8 "$h4" "$w4"
    echo ""

    printf "%s" "$(__repeat_char "$w1" '-')"
    printf -- "-+-%s" "$(__repeat_char "$w2" '-')"
    printf -- "-+-%s" "$(__repeat_char "$w3" '-')"
    printf -- "-+-%s" "$(__repeat_char "$w4" '-')"
    echo ""

    for r in "${rows[@]}"; do
        IFS='|' read -r c1 c2 c3 c4 <<< "$r"
        local f2 f3 f4
        f2="$(__fmt_cell "$fmt2" "$c2")"
        f3="$(__fmt_cell "$fmt3" "$c3")"
        f4="$(__fmt_cell "$fmt4" "$c4")"

        __pad_right_u8 "$c1" "$w1"; printf " | "; __pad_left_u8 "$f2" "$w2"; printf " | "; __pad_left_u8 "$f3" "$w3"; printf " | "; __pad_left_u8 "$f4" "$w4"
        echo ""
    done
    echo ""
}

__display_results() {
    local title="$1"
    local -n scores="$2"
    local -n ranks="$3"
    local alts_array_name="${4:-}"

    # Определяем, какие альтернативы печатать
    local -a alts=()

    if [[ -n "$alts_array_name" ]]; then
        local -n _alts_ref="$alts_array_name"
        alts=( "${_alts_ref[@]}" )
    elif (( ${#ALT_NAMES[@]} > 0 )); then
        alts=( "${ALT_NAMES[@]}" )
    else
        local k
        for k in "${!scores[@]}"; do
            alts+=( "$k" )
        done
        IFS=$'\n' alts=( $(LC_ALL=C printf '%s\n' "${alts[@]}" | sort) )
        unset IFS
    fi

    local -a rows=()
    local alt
    for alt in "${alts[@]}"; do
        rows+=( "$alt|${scores[$alt]:-0}|${ranks[$alt]:-0}" )
    done

    __print_table_3 \
        "$title:" \
        "Альтернатива" "Оценка" "Ранг" \
        "%0.4f" "%0.1f" \
        "${rows[@]}"
}

# === КАЛЬКУЛЯТОР BC ===
bc_init() {
    [ -n "${BC_PROC_PID-}" ] && return 0

    BC_INPUT=$(mktemp -u)
    BC_OUTPUT=$(mktemp -u)

    mkfifo "$BC_INPUT" 2>/dev/null || return 1
    mkfifo "$BC_OUTPUT" 2>/dev/null || return 1

    bc -l < "$BC_INPUT" > "$BC_OUTPUT" 2>/dev/null &
    BC_PROC_PID=$!

    exec 5>"$BC_INPUT"
    exec 6<"$BC_OUTPUT"

    # Инициализация: scale и функции-утилиты
    bc_write "scale=${bcsc:-6}"
    bc_write 'define abs(x) { if (x < 0) return (-x); return (x); }'
    bc_write 'define min(a,b) { if (a < b) return (a); return (b); }'
    bc_write 'define max(a,b) { if (a > b) return (a); return (b); }'

    return 0
}

bc_write() {
    [[ -z "${BC_PROC_PID-}" ]] && bc_init
    [[ -z "${BC_PROC_PID-}" ]] && return 1

    echo "$1" >&5 2>/dev/null && return 0

    # Если запись не удалась — перезапускаем bc
    bc_cleanup
    bc_init || return 1
    echo "$1" >&5 2>/dev/null
}

bc_read() {
    [[ -z "${BC_PROC_PID-}" ]] && { echo "0"; return 1; }

    local result
    if read -t 1 -r result <&6 2>/dev/null; then
        echo "$result"
        return 0
    fi

    echo "0"
    return 1
}

bc_calc() {
    local expression="$1" scale="${2:-6}" default="${3:-0}"

    [[ -z "${BC_PROC_PID-}" ]] && bc_init

    if [[ -z "$expression" ]]; then
        echo "$default"
        return 1
    fi

    # Нормализация десятичного разделителя и трим
    expression=$(echo "$expression" | tr ',' '.' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Отправляем выражение в bc (1 значение на строку)
    bc_write "scale=$scale; ($expression)"

    local result
    result=$(bc_read)
    result=$(echo "$result" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Пустой/NaN/Inf -> default
    if [[ -z "$result" || "$result" == "nan" || "$result" == "inf" ]]; then
        echo "$default"
        return 1
    fi

    # Нормализуем ".xxx" -> "0.xxx" и "-.xxx" -> "-0.xxx"
    if [[ "$result" == .* ]]; then
        result="0$result"
    elif [[ "$result" == -.* ]]; then
        result="-0${result:1}"
    fi

    # Если это всё равно не похоже на число — default
    if ! [[ "$result" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        echo "$default"
        return 1
    fi

    # Форматирование
    result=$(LC_NUMERIC=C printf "%.${scale}f" "$result" 2>/dev/null) || {
        echo "$default"
        return 1
    }

    # Убираем хвостовые нули
    if [[ "$result" == *.* ]]; then
        result=$(echo "$result" | sed -E 's/0+$//; s/[.]$//')
    fi

    [[ -z "$result" ]] && result="0"
    echo "$result"
}

bc_compare() {
    local a="$1" b="$2" op="$3"
    local bc_op

    a=$(echo "$a" | tr ',' '.')
    b=$(echo "$b" | tr ',' '.')

    case "$op" in
        gt) bc_op=">" ;;
        lt) bc_op="<" ;;
        ge) bc_op=">=" ;;
        le) bc_op="<=" ;;
        eq) bc_op="==" ;;
        *) return 1 ;;
    esac

    bc_write "scale=0; print ( ($a) $bc_op ($b) ), \"\n\""
    local r
    r=$(bc_read)
    [[ "$r" == "1" ]]
}

bc_cleanup() {
    [[ -z "$BC_PROC_PID" ]] && return

    # Закрываем дескрипторы 5 и 6
    exec 5>&- 2>/dev/null
    exec 6<&- 2>/dev/null

    # Завершаем процесс, если он еще жив
    if kill -0 "$BC_PROC_PID" 2>/dev/null; then
        kill "$BC_PROC_PID" 2>/dev/null
        # Ждем завершения, подавляя ошибки, если процесс не дочерний
        wait "$BC_PROC_PID" 2>/dev/null || true
    fi

    # Удаляем FIFO
    [[ -f "$BC_INPUT" ]] && rm -f "$BC_INPUT" 2>/dev/null
    [[ -f "$BC_OUTPUT" ]] && rm -f "$BC_OUTPUT" 2>/dev/null

    unset BC_PROC_PID BC_INPUT BC_OUTPUT
}

# === УПРАВЛЕНИЕ ДАННЫМИ ===
data_cleanup() {
    zenity_progress_stop 2>/dev/null
    bc_cleanup 2>/dev/null

    # Очистка основных массивов
    ALT_NAMES=()
    CRITERIA_NAMES=()

    # Очистка ассоциативных массивов
    unset FUZZY_WEIGHTS 2>/dev/null; declare -gA FUZZY_WEIGHTS
    unset FUZZY_RATINGS 2>/dev/null; declare -gA FUZZY_RATINGS

    # Очистка результатов
    unset RESULTS_1 2>/dev/null; declare -gA RESULTS_1
    unset RESULTS_2 2>/dev/null; declare -gA RESULTS_2
    unset RESULTS_3 2>/dev/null; declare -gA RESULTS_3
    unset RESULTS_4 2>/dev/null; declare -gA RESULTS_4

    unset RANKS_1 2>/dev/null; declare -gA RANKS_1
    unset RANKS_2 2>/dev/null; declare -gA RANKS_2
    unset RANKS_3 2>/dev/null; declare -gA RANKS_3
    unset RANKS_4 2>/dev/null; declare -gA RANKS_4

    unset NORMALIZED_1 2>/dev/null; declare -gA NORMALIZED_1
    unset NORMALIZED_2 2>/dev/null; declare -gA NORMALIZED_2
    unset NORMALIZED_3 2>/dev/null; declare -gA NORMALIZED_3
    unset NORMALIZED_4 2>/dev/null; declare -gA NORMALIZED_4

    # Очистка нечеткой системы
    unset FUZZY_TERMS 2>/dev/null; declare -gA FUZZY_TERMS
    unset OUTPUT_TERMS 2>/dev/null; declare -gA OUTPUT_TERMS
    unset OUTPUT_CENTROIDS 2>/dev/null; declare -gA OUTPUT_CENTROIDS

    FUZZY_RULES=()
    FUZZY_INPUT_VARS=()

    # Очистка технических переменных
    CURRENT_TEMPLATE=""

    [[ -n "${PROGRESS_FILE-}" && -f "${PROGRESS_FILE-}" ]] && rm -f "$PROGRESS_FILE" 2>/dev/null
    unset PROGRESS_FILE PROGRESS_PID 2>/dev/null

    echo "Все данные очищены" >&2
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
    local current_section=""
    local errors=0

    # Сброс всех массивов перед загрузкой
    data_cleanup

    echo "Начинаем импорт данных..." >&2

    while IFS= read -r line; do
        line=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [ -z "$line" ] && continue

        # Определяем секцию
        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            echo "Загружаем секцию: $current_section" >&2
            continue
        fi

        case "$current_section" in
            "Альтернативы")
                IFS=',' read -ra alts <<< "$line"
                for alt in "${alts[@]}"; do
                    alt=$(echo "$alt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    [ -n "$alt" ] && ALT_NAMES+=("$alt")
                done
                ;;

            "Критерии")
                IFS=',' read -ra crits <<< "$line"
                for crit in "${crits[@]}"; do
                    crit=$(echo "$crit" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    [ -n "$crit" ] && CRITERIA_NAMES+=("$crit")
                done
                ;;

            "Нечеткие_веса")
                if [[ "$line" =~ ^([^:]+):([0-9.]+),([0-9.]+),([0-9.]+)$ ]]; then
                    local crit="${BASH_REMATCH[1]}"
                    local low="${BASH_REMATCH[2]}"
                    local mid="${BASH_REMATCH[3]}"
                    local high="${BASH_REMATCH[4]}"

                    # Проверка на треугольное число
                    if [ "$(echo "$low <= $mid && $mid <= $high" | bc -l 2>/dev/null)" = "1" ]; then
                        FUZZY_WEIGHTS["$crit,low"]=$low
                        FUZZY_WEIGHTS["$crit,mid"]=$mid
                        FUZZY_WEIGHTS["$crit,high"]=$high
                    else
                        echo "ОШИБКА: Некорректное треугольное число для '$crit': $low, $mid, $high" >&2
                        ((errors++))
                    fi
                else
                    echo "ОШИБКА: Неверный формат нечеткого веса: '$line'" >&2
                    ((errors++))
                fi
                ;;

            "Нечеткие_оценки")
                if [[ "$line" =~ ^([^:]+):([^:]+):([0-9.]+),([0-9.]+),([0-9.]+)$ ]]; then
                    local alt="${BASH_REMATCH[1]}"
                    local crit="${BASH_REMATCH[2]}"
                    local low="${BASH_REMATCH[3]}"
                    local mid="${BASH_REMATCH[4]}"
                    local high="${BASH_REMATCH[5]}"

                    # Проверка на треугольное число
                    if [ "$(echo "$low <= $mid && $mid <= $high" | bc -l 2>/dev/null)" = "1" ]; then
                        FUZZY_RATINGS["$alt,$crit,low"]=$low
                        FUZZY_RATINGS["$alt,$crit,mid"]=$mid
                        FUZZY_RATINGS["$alt,$crit,high"]=$high
                    else
                        echo "ОШИБКА: Некорректное треугольное число для '$alt:$crit': $low, $mid, $high" >&2
                        ((errors++))
                    fi
                else
                    echo "ОШИБКА: Неверный формат нечеткой оценки: '$line'" >&2
                    ((errors++))
                fi
                ;;

            "Нечеткая_система")
                # Входные термы
                if [[ "$line" =~ ^ВХОДНЫЕ\.([^.]+)\.([^=]+)=([0-9.,]+)$ ]]; then
                    local crit="${BASH_REMATCH[1]}"
                    local term="${BASH_REMATCH[2]}"
                    local values="${BASH_REMATCH[3]}"

                    IFS=',' read -r low mid high <<< "$values"

                    # Проверка и сохранение
                    if [ "$(echo "$low <= $mid && $mid <= $high" | bc -l 2>/dev/null)" = "1" ]; then
                        FUZZY_TERMS["$crit,$term,low"]=$low
                        FUZZY_TERMS["$crit,$term,mid"]=$mid
                        FUZZY_TERMS["$crit,$term,high"]=$high

                        # Запоминаем входные переменные
                        if [[ ! " ${FUZZY_INPUT_VARS[*]} " =~ " $crit " ]]; then
                            FUZZY_INPUT_VARS+=("$crit")
                        fi
                    else
                        echo "ОШИБКА: Некорректный терм '$crit.$term': $low, $mid, $high" >&2
                        ((errors++))
                    fi

                # Выходные термы
                elif [[ "$line" =~ ^ВЫХОДНЫЕ\.([^.]+)\.([^=]+)=([0-9.,]+)$ ]]; then
                    local var="${BASH_REMATCH[1]}"
                    local term="${BASH_REMATCH[2]}"
                    local values="${BASH_REMATCH[3]}"

                    IFS=',' read -r low mid high <<< "$values"

                    if [ "$(echo "$low <= $mid && $mid <= $high" | bc -l 2>/dev/null)" = "1" ]; then
                        OUTPUT_TERMS["$term,low"]=$low
                        OUTPUT_TERMS["$term,mid"]=$mid
                        OUTPUT_TERMS["$term,high"]=$high
                    else
                        echo "ОШИБКА: Некорректный выходной терм '$term': $low, $mid, $high" >&2
                        ((errors++))
                    fi

                # Правила
                elif [[ "$line" =~ ^ПРАВИЛО[0-9]*=(.+)$ ]] || [[ "$line" =~ ^(ЕСЛИ|Если|если).*(ТО|То|то) ]]; then
                    local rule_text
                    if [[ "$line" =~ ^ПРАВИЛО[0-9]*=(.+)$ ]]; then
                        rule_text="${BASH_REMATCH[1]}"
                    else
                        rule_text="$line"
                    fi

                    rule_text=$(echo "$rule_text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    if [ -n "$rule_text" ]; then
                        FUZZY_RULES+=("$rule_text")
                    fi
                fi
                ;;
        esac
    done <<< "$template"

    # Проверка полноты данных
    if [ ${#ALT_NAMES[@]} -eq 0 ]; then
        echo "ОШИБКА: Не загружены альтернативы" >&2
        ((errors++))
    fi

    if [ ${#CRITERIA_NAMES[@]} -eq 0 ]; then
        echo "ОШИБКА: Не загружены критерии" >&2
        ((errors++))
    fi

    # Автозаполнение отсутствующих оценок нулями
    for alt in "${ALT_NAMES[@]}"; do
        for crit in "${CRITERIA_NAMES[@]}"; do
            for level in low mid high; do
                if [ -z "${FUZZY_RATINGS[$alt,$crit,$level]+isset}" ]; then
                    FUZZY_RATINGS["$alt,$crit,$level"]=0
                fi
            done
        done
    done

    # Сохраняем шаблон
    CURRENT_TEMPLATE="$template"

    echo "Импорт завершен. Ошибок: $errors" >&2
    echo "Итог:" >&2
    echo "  Альтернатив: ${#ALT_NAMES[@]}" >&2
    echo "  Критериев: ${#CRITERIA_NAMES[@]}" >&2
    echo "  Правил: ${#FUZZY_RULES[@]}" >&2
    echo "  Входных переменных нечеткой системы: ${#FUZZY_INPUT_VARS[@]}" >&2

    return $((errors > 0 ? 1 : 0))
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
        --title="Редактирование шаблона данных задачи 9" \
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
            --text="Шаблон успешно импортирован!\n\n• Альтернатив: ${#ALT_NAMES[@]}\n• Критериев: ${#CRITERIA_NAMES[@]}\n• Правил: ${#FUZZY_RULES[@]}" \
            --width=450 2>/dev/null
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

    echo "Валидация данных задачи 9..." >&2

    # Проверка базовых структур
    if [[ ${#ALT_NAMES[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы альтернативы" >&2
        errors=1
    else
        echo "  Альтернатив: ${#ALT_NAMES[@]}" >&2
    fi

    if [[ ${#CRITERIA_NAMES[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы критерии" >&2
        errors=1
    else
        echo "  Критериев: ${#CRITERIA_NAMES[@]}" >&2
    fi

    # Проверка наличия всех оценок
    for alt in "${ALT_NAMES[@]}"; do
        for crit in "${CRITERIA_NAMES[@]}"; do
            for level in low mid high; do
                if [[ -z "${FUZZY_RATINGS[$alt,$crit,$level]+isset}" ]]; then
                    echo "Предупреждение: отсутствует оценка для альтернативы '$alt', критерия '$crit', уровень '$level'" >&2
                    ((warnings++))
                fi
            done
        done
    done

    # Проверка нечеткой системы
    if [[ ${#FUZZY_RULES[@]} -eq 0 ]]; then
        echo "Предупреждение: не заданы нечеткие правила" >&2
        ((warnings++))
    else
        echo "  Правил: ${#FUZZY_RULES[@]}" >&2
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


# === ПРОВЕРКА ЗАВИСИМОСТЕЙ ===
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
        subtask1_fuzzy_weights
        subtask2_normalized_weights
        subtask3_comparison
        subtask4_fuzzy_inference
      )
      ;;
  *) zenity_main_menu ;;
esac
