#!/bin/bash

# === ПЕРЕМЕННЫЕ ===
declare -a ALT_NAMES STATE_NAMES
declare -A PAYOFFS PROBS
declare CURRENT_KNOWN_STATE CURRENT_ALPHA_HURWITZ
declare PROGRESS_FILE PROGRESS_PID bcsc=6

DEFAULT_TEMPLATE=$(cat <<'EOF'
# ШАБЛОН ДАННЫХ ДЛЯ ЗАДАЧИ 7:

[Альтернативы]
UBUNTU, FEDORA, ASTRA_LINUX, ALT_LINUX, CALCULATE_LINUX

[Состояния среды]
ГОСУДАРСТВЕННЫЙ_СЕКТОР, КОРПОРАТИВНЫЙ_СЕКТОР, ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР, КРИТИЧЕСКИЕ_СИСТЕМЫ

[Объяснение состояний]
ГОСУДАРСТВЕННЫЙ_СЕКТОР=Внедрение в органы государственной власти и связанные структуры. Ключевые требования: сертификация ФСТЭК/ФСБ, соответствие регуляторным нормам, доверенная цепочка поставки.
КОРПОРАТИВНЫЙ_СЕКТОР=Использование в коммерческих компаниях РФ (SMB и enterprise). Требования: стабильность, предсказуемые обновления, адекватная поддержка, совместимость с типовыми бизнес-приложениями.
ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР=Развёртывание в школах, колледжах и вузах. Требования: минимальная стоимость владения, простота освоения, наличие учебных материалов и активного сообщества.
КРИТИЧЕСКИЕ_СИСТЕМЫ=Промышленная автоматизация, инфраструктура, системы с повышенной ответственностью. Требования: максимальная надёжность, строгие требования к безопасности, длительный цикл поддержки.

[Матрица выигрышей]
# Формат: АЛЬТЕРНАТИВА:ГОСУДАРСТВЕННЫЙ_СЕКТОР,КОРПОРАТИВНЫЙ_СЕКТОР,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,КРИТИЧЕСКИЕ_СИСТЕМЫ
UBUNTU:80,90,95,78
FEDORA:65,70,85,60
ASTRA_LINUX:90,78,65,92
ALT_LINUX:85,88,75,88
CALCULATE_LINUX:78,80,80,75

[Объяснение оценок]
UBUNTU=В корпоративном и образовательном сегментах Ubuntu выступает универсальным решением: сочетает бесплатность, стабильные LTS-ветки, богатую документацию и широкое сообщество, поэтому получает высокие оценки в КОРПОРАТИВНОМ и ОБРАЗОВАТЕЛЬНОМ секторах; в ГОССЕКТОРЕ и КРИТИЧЕСКИХ СИСТЕМАХ пригодность ниже из-за отсутствия специализированных сертифицированных редакций.
FEDORA=Fedora рассматривается как платформа для разработки и тестирования, а не как консервативный production: быстрая смена версий и менее предсказуемые обновления снижают её ценность в ГОССЕКТОРЕ, КОРПОРАТИВНОМ сегменте и КРИТИЧЕСКИХ СИСТЕМАХ, но в ОБРАЗОВАТЕЛЬНОМ контексте она остаётся приемлемой как современная обучающая среда.
ASTRA_LINUX=Astra Linux специализируется на ГОСУДАРСТВЕННОМ_СЕКТОРЕ и КРИТИЧЕСКИХ_СИСТЕМАХ: высокая безопасность, сертификация ФСТЭК/ФСБ и ориентация на защищённые конфигурации обеспечивают лидирующие оценки в этих состояниях среды; при этом в КОРПОРАТИВНОМ и особенно ОБРАЗОВАТЕЛЬНОМ сегментах её высокая стоимость и специфичность делают её менее удобным и оправданным выбором.
ALT_LINUX=ALT Linux выступает как сбалансированное решение для российского КОРПОРАТИВНОГО_СЕКТОРА и ряда сценариев ГОССЕКТОРА/КРИТИЧЕСКИХ_СИСТЕМ: хорошие показатели стабильности и безопасности, наличие сертифицированных редакций и разумная стоимость дают высокие оценки в этих состояниях; в ОБРАЗОВАТЕЛЬНОМ контексте он несколько уступает Ubuntu по простоте и массе учебных материалов.
CALCULATE_LINUX=Calculate Linux ориентирован на практические business-/desktop-сценарии и предоставляет стабильную базу при умеренной стоимости; в КОРПОРАТИВНОМ и ОБРАЗОВАТЕЛЬНОМ секторах он показывает хорошие, но не рекордные значения, а в ГОССЕКТОРЕ и КРИТИЧЕСКИХ_СИСТЕМАХ его отсутствие широких сертификаций и меньшая известность ограничивают оценку пригодности.

[Вероятности]
0.30,0.40,0.20,0.10

[Объяснение вероятностей]
ГОСУДАРСТВЕННЫЙ_СЕКТОР=0.30 - Существенная доля внедрений связана с курсом на импортозамещение и требованиями к использованию отечественных решений в государственных структурах.
КОРПОРАТИВНЫЙ_СЕКТОР=0.40 - Наиболее обширный сегмент рынка Linux-решений: коммерческие компании различных масштабов, для которых Linux становится инфраструктурным стандартом.
ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР=0.20 - Постепенное, но устойчивое распространение Linux в образовании, обусловленное стремлением снизить затраты и расширить доступ к современным инструментам.
КРИТИЧЕСКИЕ_СИСТЕМЫ=0.10 - Относительно небольшой по объёму, но стратегически важный сегмент, где выбор платформы определяется жёсткими требованиями по безопасности и надёжности.

[Параметры]
ИЗВЕСТНОЕ_СОСТОЯНИЕ=ГОСУДАРСТВЕННЫЙ_СЕКТОР
АЛЬФА_ГУРВИЦА=0.65
EOF
)

# === ИНТЕРФЕЙС ===
zenity_show_conditions() {
    if ! data_validate; then
        zenity --error --title="Ошибка данных" \
            --text="Данные не загружены или повреждены.\nЗагрузите данные заново." --width=500 2>/dev/null
        return
    fi

    local conditions_text="ЗАДАЧА 7: ОДНОКРИТЕРИАЛЬНЫЙ ВЫБОР В УСЛОВИЯХ НЕОПРЕДЕЛЕННОСТИ

ЦЕЛЬ:
Выбрать оптимальную альтернативу при неопределенности состояний среды (один критерий).

ТРИ СИТУАЦИИ АНАЛИЗА:
1. Определенность
   - Известно состояние среды: $CURRENT_KNOWN_STATE
   - Метод: выбор максимума в известном состоянии

2. Риск (вероятности известны)
   - Метод: критерий Байеса
   - Формула: EMV(A) = Σ P(S) × V(A,S)

3. Полная неопределенность (вероятности неизвестны)
   - Методы:
     1. Лапласа - равные вероятности
     2. Вальда - максимизация минимума
     3. Сэвиджа - минимизация максимального риска
     4. Гурвица - компромисс (α=$CURRENT_ALPHA_HURWITZ)

ДАННЫЕ:
• Альтернатив: ${#ALT_NAMES[@]}
• Состояний среды: ${#STATE_NAMES[@]}
• Коэффициент Гурвица: α = $CURRENT_ALPHA_HURWITZ"

    echo "$conditions_text" | zenity --text-info --title="Задача 7" \
        --width=700 --height=600 --font="monospace 10" 2>/dev/null || true
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
            --title="Задача 7: Принятие решений в условиях неопределенности" \
            --text="Действие:" \
            --column="Опция" \
            "▶ Выполнить все задачи" \
            "1. Анализ определенности" \
            "2. Анализ риска (Байес)" \
            "3. Анализ неопределенности" \
            "4. Итоговые выводы" \
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
            "1. Анализ определенности")
                { subtask1_certainty; } | zenity --text-info \
                    --title="Задача 1" \
                    --width=600 --height=550 --font="monospace 10" 2>/dev/null || subtask1_certainty
                ;;
            "2. Анализ риска (Байес)")
                { subtask2_risk; } | zenity --text-info \
                    --title="Задача 2" \
                    --width=700 --height=550 --font="monospace 10" 2>/dev/null || subtask2_risk
                ;;
            "3. Анализ неопределенности")
                { subtask3_uncertainty; } | zenity --text-info \
                    --title="Задача 3" \
                    --width=650 --height=800 --font="monospace 10" 2>/dev/null || subtask3_uncertainty
                ;;
            "4. Итоговые выводы")
                { subtask4_conclusions; } | zenity --text-info \
                    --title="Задача 4" \
                    --width=600 --height=600 --font="monospace 10" 2>/dev/null || subtask4_conclusions
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

    zenity_progress_start "Решение задачи 7" "Подготовка данных..."

    {
        echo "=== РЕШЕНИЕ ЗАДАЧИ 7 ==="
        echo ""

        echo "10" >&3
        echo "# 1. Анализ матрицы выигрышей..." >&3
        __display_payoff_matrix

        echo "25" >&3
        echo "# 2. Анализ определенности..." >&3
        subtask1_certainty

        echo "45" >&3
        echo "# 3. Анализ риска..." >&3
        subtask2_risk

        echo "65" >&3
        echo "# 4. Анализ неопределенности..." >&3
        subtask3_uncertainty

        echo "85" >&3
        echo "# 5. Формирование выводов..." >&3
        subtask4_conclusions

        echo "100" >&3
        echo "# Вычисления завершены" >&3
        sleep 0.5

    } > "$temp_file" 2>&1

    zenity_progress_stop

    cat "$temp_file" | zenity --text-info \
        --title="Решение задачи 7" \
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
__display_payoff_matrix() {
    echo "МАТРИЦА ВЫИГРЫШЕЙ"
    echo "================="
    echo ""
    echo "Обозначение: V(A,S) — выигрыш альтернативы A при состоянии среды S."
    echo ""

    local alt_count=${#ALT_NAMES[@]}
    local state_count=${#STATE_NAMES[@]}

    if [[ $alt_count -eq 0 || $state_count -eq 0 ]]; then
        echo "Нет данных: альтернативы или состояния среды не заданы."
        echo ""
        return 1
    fi

    # Короткие метки состояний S1..Sn
    declare -a state_labels
    for ((s=0; s<state_count; s++)); do
        state_labels[$s]="S$((s+1))"
    done

    echo "СОПОСТАВЛЕНИЕ СОСТОЯНИЙ:"
    for ((s=0; s<state_count; s++)); do
        echo "  ${state_labels[$s]} = ${STATE_NAMES[$s]}"
    done
    echo ""

    # Формируем заголовки и форматы
    local -a headers=("A \\ S")
    local -a fmts=("%-s")
    for ((s=0; s<state_count; s++)); do
        headers+=("${state_labels[$s]}")
        fmts+=("%.0f")
    done

    # Формируем строки данных
    local -a rows=()
    for ((a=0; a<alt_count; a++)); do
        local row="${ALT_NAMES[$a]}"
        for ((s=0; s<state_count; s++)); do
            row+="|${PAYOFFS[$a,$s]:-0}"
        done
        rows+=("$row")
    done

    __print_table_flex "" "$((state_count + 1))" "${headers[@]}" "${fmts[@]}" "${rows[@]}"

    # Вероятности (если заданы)
    if [ ${#PROBS[@]} -gt 0 ]; then
        echo "ВЕРОЯТНОСТИ СОСТОЯНИЙ (как заданы в данных):"

        # Важно: первый заголовок делаем пустым (или пробел),
        # а "P(S)" — это именно подпись строки.
        local -a prob_headers=(" ")
        local -a prob_fmts=("%-s")
        for ((s=0; s<state_count; s++)); do
            prob_headers+=("${state_labels[$s]}")
            prob_fmts+=("%.3f")
        done

        local prob_row="P(S)"
        for ((s=0; s<state_count; s++)); do
            prob_row+="|${PROBS[$s]:-0}"
        done

        __print_table_flex "" "$((state_count + 1))" "${prob_headers[@]}" "${prob_fmts[@]}" "$prob_row"

        local prob_sum=0
        for ((s=0; s<state_count; s++)); do
            prob_sum=$(bc_calc "$prob_sum + ${PROBS[$s]:-0}")
        done
        echo "Сумма P(S): $(LC_NUMERIC=C printf "%.3f" "$prob_sum")"
        echo ""
    fi

    echo "ПАРАМЕТРЫ:"
    echo "  • Коэффициент Гурвица α = $CURRENT_ALPHA_HURWITZ"
    echo "  • Известное состояние (для случая определенности): $CURRENT_KNOWN_STATE"
    echo ""
}

subtask1_certainty() {
    echo "ЗАДАЧА 1: СИТУАЦИЯ ОПРЕДЕЛЕННОСТИ"
    echo "================================="
    echo ""
    echo "Условие: состояние среды известно и равно S* = $CURRENT_KNOWN_STATE."
    echo "Правило выбора: A* = argmax_A V(A, S*)."
    echo ""

    local alt_count=${#ALT_NAMES[@]}
    local state_count=${#STATE_NAMES[@]}

    local known_state_idx=-1
    for ((s=0; s<state_count; s++)); do
        if [[ "${STATE_NAMES[$s]}" == "$CURRENT_KNOWN_STATE" ]]; then
            known_state_idx=$s
            break
        fi
    done

    if [[ $known_state_idx -eq -1 ]]; then
        echo "ОШИБКА: состояние '$CURRENT_KNOWN_STATE' не найдено."
        echo "Доступные состояния: ${STATE_NAMES[*]}"
        echo ""
        return 1
    fi

    local max_payoff=-999999
    local best_alt=""
    declare -A payoffs

    for ((a=0; a<alt_count; a++)); do
        local alt="${ALT_NAMES[$a]}"
        local payoff="${PAYOFFS[$a,$known_state_idx]:-0}"
        payoffs["$alt"]="$payoff"
        if bc_compare "$payoff" "$max_payoff" "gt"; then
            max_payoff="$payoff"
            best_alt="$alt"
        fi
    done

    echo "СРАВНЕНИЕ ВЫИГРЫШЕЙ В СОСТОЯНИИ S*:"
    local -a rows=()
    for alt in "${ALT_NAMES[@]}"; do
        local p="${payoffs[$alt]:-0}"
        local mark=""
        if bc_compare "$p" "$max_payoff" "eq"; then
            mark="*"
        fi
        rows+=("$alt|$p|$mark")
    done

    __print_table_flex "" 3 \
        "Альтернатива" "V(A,S*)" "" \
        "%-s" "%.0f" "%-s" \
        "${rows[@]}"

    echo "* — максимум (оптимум в ситуации определенности)"
    echo ""

    echo "РЕЗУЛЬТАТ:"
    echo "  • A* = $best_alt"
    echo "  • V(A*, S*) = $(LC_NUMERIC=C printf "%.0f" "$max_payoff")"
    echo ""
}

subtask2_risk() {
    echo "ЗАДАЧА 2: СИТУАЦИЯ РИСКА (КРИТЕРИЙ БАЙЕСА)"
    echo "=========================================="
    echo ""
    echo "Условие: вероятности состояний известны."
    echo "Оценка: EMV(A) = Σ P(S)·V(A,S)."
    echo ""

    local alt_count=${#ALT_NAMES[@]}
    local state_count=${#STATE_NAMES[@]}

    normalize_probabilities >/dev/null 2>&1

    echo "ВЕРОЯТНОСТИ СОСТОЯНИЙ (после нормализации):"
    for ((s=0; s<state_count; s++)); do
        LC_NUMERIC=C printf "  S%-2d = %-28s : %0.3f\n" \
            "$((s+1))" "${STATE_NAMES[$s]}" "${PROBS[$s]:-0}"
    done
    local prob_sum=0
    for ((s=0; s<state_count; s++)); do
        prob_sum=$(bc_calc "$prob_sum + ${PROBS[$s]:-0}")
    done
    echo "  ΣP(S) = $(LC_NUMERIC=C printf "%.3f" "$prob_sum")"
    echo ""

    declare -A expected_values
    local max_expected=-999999
    local best_alt=""

    echo "РАСЧЕТ EMV ПО АЛЬТЕРНАТИВАМ:"
    for ((a=0; a<alt_count; a++)); do
        local alt="${ALT_NAMES[$a]}"
        local expected=0
        local expr="EMV($alt) = "

        for ((s=0; s<state_count; s++)); do
            local payoff="${PAYOFFS[$a,$s]:-0}"
            local prob="${PROBS[$s]:-0}"
            local term
            term=$(bc_calc "$payoff * $prob")
            expected=$(bc_calc "$expected + $term")

            if [[ $s -gt 0 ]]; then expr+=" + "; fi
            expr+="${payoff}×$(LC_NUMERIC=C printf "%0.3f" "$prob")"
        done

        expected_values["$alt"]="$expected"
        expr+=" = $(LC_NUMERIC=C printf "%0.2f" "$expected")"

        echo "  $expr"

        if bc_compare "$expected" "$max_expected" "gt"; then
            max_expected="$expected"
            best_alt="$alt"
        fi
    done
    echo ""

    echo "ИТОГ (Байес):"
    echo "  • A* = $best_alt"
    echo "  • max EMV = $(LC_NUMERIC=C printf "%0.2f" "$max_expected")"
    echo ""
}

subtask3_uncertainty() {
    echo "ЗАДАЧА 3: ПОЛНАЯ НЕОПРЕДЕЛЕННОСТЬ"
    echo "================================="
    echo ""
    echo "Условие: вероятности состояний неизвестны."
    echo "Рассматриваются критерии: Лапласа, Вальда, Сэвиджа, Гурвица."
    echo ""

    local alt_count=${#ALT_NAMES[@]}
    local state_count=${#STATE_NAMES[@]}

    # 1) Лаплас
    echo "1) КРИТЕРИЙ ЛАПЛАСА"
    echo "   Предположение: P(S) = 1/n, n = $state_count."
    echo "   L(A) = (Σ V(A,S)) / n."
    echo ""

    local equal_prob
    equal_prob=$(bc_calc "1 / $state_count")

    local max_laplace=-999999
    local best_laplace=""
    declare -A laplace_values laplace_sums

    for ((a=0; a<alt_count; a++)); do
        local alt="${ALT_NAMES[$a]}"
        local sum=0
        for ((s=0; s<state_count; s++)); do
            sum=$(bc_calc "$sum + ${PAYOFFS[$a,$s]:-0}")
        done
        local laplace
        laplace=$(bc_calc "$sum * $equal_prob")
        laplace_sums["$alt"]="$sum"
        laplace_values["$alt"]="$laplace"
        if bc_compare "$laplace" "$max_laplace" "gt"; then
            max_laplace="$laplace"
            best_laplace="$alt"
        fi
    done

    local -a rows=()
    for alt in "${ALT_NAMES[@]}"; do
        local mark=""
        [[ "$alt" == "$best_laplace" ]] && mark="*"
        rows+=("$alt|${laplace_sums[$alt]:-0}|${laplace_values[$alt]:-0}|$mark")
    done

    __print_table_flex "" 4 \
        "Альтернатива" "ΣV" "L(A)" "" \
        "%-s" "%.0f" "%.2f" "%-s" \
        "${rows[@]}"

    echo "* — оптимум по Лапласу"
    echo "  Результат: $best_laplace (L = $(LC_NUMERIC=C printf "%0.2f" "$max_laplace"))"
    echo ""

    # 2) Вальд
    echo "2) КРИТЕРИЙ ВАЛЬДА (maximin)"
    echo "   W(A) = min_S V(A,S), выбираем max W(A)."
    echo ""

    local best_wald=""
    local max_min=-999999
    declare -A min_values

    for ((a=0; a<alt_count; a++)); do
        local alt="${ALT_NAMES[$a]}"
        local min_val="${PAYOFFS[$a,0]:-0}"
        for ((s=1; s<state_count; s++)); do
            local val="${PAYOFFS[$a,$s]:-0}"
            if bc_compare "$val" "$min_val" "lt"; then
                min_val="$val"
            fi
        done
        min_values["$alt"]="$min_val"
        if bc_compare "$min_val" "$max_min" "gt"; then
            max_min="$min_val"
            best_wald="$alt"
        fi
    done

    rows=()
    for alt in "${ALT_NAMES[@]}"; do
        local mark=""
        [[ "$alt" == "$best_wald" ]] && mark="*"
        rows+=("$alt|${min_values[$alt]:-0}|$mark")
    done

    __print_table_flex "" 3 \
        "Альтернатива" "W(A)=min" "" \
        "%-s" "%.0f" "%-s" \
        "${rows[@]}"

    echo "* — оптимум по Вальду"
    echo "  Результат: $best_wald (W = $(LC_NUMERIC=C printf "%0.0f" "$max_min"))"
    echo ""

    # 3) Сэвидж
    echo "3) КРИТЕРИЙ СЭВИДЖА (minimax regret)"
    echo "   Для каждого S: M(S)=max_A V(A,S)."
    echo "   Риск (сожаление): R(A,S)=M(S)-V(A,S)."
    echo "   S(A)=max_S R(A,S), выбираем min S(A)."
    echo ""

    declare -a column_max
    for ((s=0; s<state_count; s++)); do
        column_max[$s]="${PAYOFFS[0,$s]:-0}"
        for ((a=1; a<alt_count; a++)); do
            if bc_compare "${PAYOFFS[$a,$s]:-0}" "${column_max[$s]:-0}" "gt"; then
                column_max[$s]="${PAYOFFS[$a,$s]:-0}"
            fi
        done
    done

    echo "Максимумы по состояниям M(S):"
    for ((s=0; s<state_count; s++)); do
        LC_NUMERIC=C printf "  S%-2d (%-28s): %0.0f\n" "$((s+1))" "${STATE_NAMES[$s]}" "${column_max[$s]}"
    done
    echo ""

    local min_max_regret=999999
    local best_savage=""
    declare -A max_regrets regret_lists

    for ((a=0; a<alt_count; a++)); do
        local alt="${ALT_NAMES[$a]}"
        local max_regret=0
        local list=""
        for ((s=0; s<state_count; s++)); do
            local regret
            regret=$(bc_calc "${column_max[$s]} - ${PAYOFFS[$a,$s]:-0}")
            [[ $s -gt 0 ]] && list+=", "
            list+=$(LC_NUMERIC=C printf "%0.0f" "$regret")
            if bc_compare "$regret" "$max_regret" "gt"; then
                max_regret="$regret"
            fi
        done
        max_regrets["$alt"]="$max_regret"
        regret_lists["$alt"]="$list"

        if bc_compare "$max_regret" "$min_max_regret" "lt"; then
            min_max_regret="$max_regret"
            best_savage="$alt"
        fi
    done

    rows=()
    for alt in "${ALT_NAMES[@]}"; do
        local mark=""
        [[ "$alt" == "$best_savage" ]] && mark="*"
        rows+=("$alt|${regret_lists[$alt]}|${max_regrets[$alt]:-0}|$mark")
    done

    __print_table_flex "" 4 \
        "Альтернатива" "R(A,S) по S" "S(A)=max" "" \
        "%-s" "%-s" "%.0f" "%-s" \
        "${rows[@]}"

    echo "* — оптимум по Сэвиджу (минимальный максимум сожаления)"
    echo "  Результат: $best_savage (S = $(LC_NUMERIC=C printf "%0.0f" "$min_max_regret"))"
    echo ""

    # 4) Гурвиц
    echo "4) КРИТЕРИЙ ГУРВИЦА"
    echo "   H(A)=α·max_S V(A,S) + (1-α)·min_S V(A,S), где α=$CURRENT_ALPHA_HURWITZ."
    echo ""

    local best_hurwitz=""
    local max_hurwitz=-999999
    declare -A hurwitz_values max_values

    for ((a=0; a<alt_count; a++)); do
        local alt="${ALT_NAMES[$a]}"
        local min_val="${PAYOFFS[$a,0]:-0}"
        local max_val="${PAYOFFS[$a,0]:-0}"

        for ((s=1; s<state_count; s++)); do
            local val="${PAYOFFS[$a,$s]:-0}"
            if bc_compare "$val" "$min_val" "lt"; then min_val="$val"; fi
            if bc_compare "$val" "$max_val" "gt"; then max_val="$val"; fi
        done

        local hurwitz
        hurwitz=$(bc_calc "$CURRENT_ALPHA_HURWITZ * $max_val + (1 - $CURRENT_ALPHA_HURWITZ) * $min_val")
        hurwitz_values["$alt"]="$hurwitz"
        max_values["$alt"]="$max_val"
        min_values["$alt"]="$min_val"

        if bc_compare "$hurwitz" "$max_hurwitz" "gt"; then
            max_hurwitz="$hurwitz"
            best_hurwitz="$alt"
        fi
    done

    rows=()
    for alt in "${ALT_NAMES[@]}"; do
        local mark=""
        [[ "$alt" == "$best_hurwitz" ]] && mark="*"
        rows+=("$alt|${min_values[$alt]:-0}|${max_values[$alt]:-0}|${hurwitz_values[$alt]:-0}|$mark")
    done

    __print_table_flex "" 5 \
        "Альтернатива" "min" "max" "H(A)" "" \
        "%-s" "%.0f" "%.0f" "%.2f" "%-s" \
        "${rows[@]}"

    echo "* — оптимум по Гурвицу"
    echo "  Результат: $best_hurwitz (H = $(LC_NUMERIC=C printf "%0.2f" "$max_hurwitz"))"
    echo ""

    # Сводная таблица
    echo "СВОДНАЯ ТАБЛИЦА (значения критериев):"
    rows=()
    for alt in "${ALT_NAMES[@]}"; do
        local lm="" wm="" sm="" hm=""
        [[ "$alt" == "$best_laplace" ]] && lm="*"
        [[ "$alt" == "$best_wald" ]] && wm="*"
        [[ "$alt" == "$best_savage" ]] && sm="*"
        [[ "$alt" == "$best_hurwitz" ]] && hm="*"

        local lapf walf savf hurf
        lapf=$(LC_NUMERIC=C printf "%.2f" "${laplace_values[$alt]:-0}")
        walf=$(LC_NUMERIC=C printf "%.0f" "${min_values[$alt]:-0}")
        savf=$(LC_NUMERIC=C printf "%.0f" "${max_regrets[$alt]:-0}")
        hurf=$(LC_NUMERIC=C printf "%.2f" "${hurwitz_values[$alt]:-0}")

        rows+=("$alt|${lapf}${lm}|${walf}${wm}|${savf}${sm}|${hurf}${hm}")
    done

    __print_table_flex "" 5 \
        "Альтернатива" "Лаплас" "Вальд" "Сэвидж" "Гурвиц" \
        "%-s" "%-s" "%-s" "%-s" "%-s" \
        "${rows[@]}"

    echo "* — оптимум по критерию"
    echo ""
}

subtask4_conclusions() {
    echo "ЗАДАЧА 4: ИТОГОВЫЕ ВЫВОДЫ"
    echo "=========================="
    echo ""

    local r_certainty="$(__get_certainty_result)"
    local r_bayes="$(__get_risk_result)"
    local r_laplace="$(__get_laplace_result)"
    local r_wald="$(__get_wald_result)"
    local r_savage="$(__get_savage_result)"
    local r_hurwitz="$(__get_hurwitz_result)"

    echo "ОПТИМАЛЬНЫЕ АЛЬТЕРНАТИВЫ ПО КРИТЕРИЯМ:"

    local -a rows=(
        "Определенность|$r_certainty"
        "Риск (Байес)|$r_bayes"
        "Лаплас|$r_laplace"
        "Вальд|$r_wald"
        "Сэвидж|$r_savage"
        "Гурвиц|$r_hurwitz"
    )

    __print_table_flex "" 2 \
        "Критерий" "Лучшая альтернатива" \
        "%-s" "%-s" \
        "${rows[@]}"

    # Частотный анализ (голосование критериев)
    declare -A votes
    ((votes["$r_certainty"]++))
    ((votes["$r_bayes"]++))
    ((votes["$r_laplace"]++))
    ((votes["$r_wald"]++))
    ((votes["$r_savage"]++))
    ((votes["$r_hurwitz"]++))

    echo "ЧАСТОТА ВЫБОРА (сколько критериев поддержали альтернативу):"
    local max_votes=0
    for alt in "${ALT_NAMES[@]}"; do
        local v="${votes[$alt]:-0}"
        (( v > max_votes )) && max_votes=$v
    done

    rows=()
    for alt in "${ALT_NAMES[@]}"; do
        local v="${votes[$alt]:-0}"
        local mark=""
        [[ "$v" -eq "$max_votes" && "$max_votes" -gt 0 ]] && mark="*"
        rows+=("$alt|$v|$mark")
    done

    __print_table_flex "" 3 \
        "Альтернатива" "Голосов" "" \
        "%-s" "%d" "%-s" \
        "${rows[@]}"

    echo "* — лидер по большинству критериев"
    echo ""

    # Итоговая рекомендация
    if [[ $max_votes -le 0 ]]; then
        echo "ИТОГ: недостаточно данных для рекомендаций (нет голосов)."
        echo ""
        return 0
    fi

    local -a leaders=()
    for alt in "${ALT_NAMES[@]}"; do
        [[ "${votes[$alt]:-0}" -eq "$max_votes" ]] && leaders+=( "$alt" )
    done

    if [[ ${#leaders[@]} -eq 1 ]]; then
        echo "РЕКОМЕНДАЦИЯ:"
        echo "  • Предпочтительная альтернатива: ${leaders[0]}"
        echo "  • Поддержка критериями: $max_votes из 6"
        echo ""
    else
        echo "РЕКОМЕНДАЦИЯ:"
        echo "  • Несколько лидеров (ничья по большинству критериев): ${leaders[*]}"
        echo "  • Поддержка критериями: $max_votes из 6"
        echo "  • Для снятия ничьей разумно: уточнить вероятности/α или добавить правило приоритета критериев."
        echo ""
    fi
}

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
__get_certainty_result() {
    local alt_count=${#ALT_NAMES[@]}
    local state_count=${#STATE_NAMES[@]}

    local known_state_idx=-1
    for ((s=0; s<state_count; s++)); do
        if [ "${STATE_NAMES[$s]}" = "$CURRENT_KNOWN_STATE" ]; then
            known_state_idx=$s
            break
        fi
    done

    [ $known_state_idx -eq -1 ] && echo "не определено"

    local max_val="${PAYOFFS[0,$known_state_idx]}"
    local best_idx=0
    for ((a=1; a<alt_count; a++)); do
        if bc_compare "${PAYOFFS[$a,$known_state_idx]}" "$max_val" "gt"; then
            max_val="${PAYOFFS[$a,$known_state_idx]}"
            best_idx=$a
        fi
    done

    echo "${ALT_NAMES[$best_idx]}"
}

__get_risk_result() {
    local alt_count=${#ALT_NAMES[@]}
    local state_count=${#STATE_NAMES[@]}

    normalize_probabilities

    local max_expected=-999999
    local best_idx=0

    for ((a=0; a<alt_count; a++)); do
        local expected=0
        for ((s=0; s<state_count; s++)); do
            expected=$(bc_calc "$expected + ${PAYOFFS[$a,$s]} * ${PROBS[$s]}")
        done

        if bc_compare "$expected" "$max_expected" "gt"; then
            max_expected=$expected
            best_idx=$a
        fi
    done

    echo "${ALT_NAMES[$best_idx]}"
}

__get_laplace_result() {
    local alt_count=${#ALT_NAMES[@]}
    local state_count=${#STATE_NAMES[@]}
    local equal_prob=$(bc_calc "1 / $state_count")

    local max_val=-999999
    local best_idx=0

    for ((a=0; a<alt_count; a++)); do
        local sum=0
        for ((s=0; s<state_count; s++)); do
            sum=$(bc_calc "$sum + ${PAYOFFS[$a,$s]}")
        done
        local laplace=$(bc_calc "$sum * $equal_prob")

        if bc_compare "$laplace" "$max_val" "gt"; then
            max_val=$laplace
            best_idx=$a
        fi
    done

    echo "${ALT_NAMES[$best_idx]}"
}

__get_wald_result() {
    local alt_count=${#ALT_NAMES[@]}
    local state_count=${#STATE_NAMES[@]}

    local max_min=-999999
    local best_idx=0

    for ((a=0; a<alt_count; a++)); do
        local min_val="${PAYOFFS[$a,0]}"
        for ((s=1; s<state_count; s++)); do
            if bc_compare "${PAYOFFS[$a,$s]}" "$min_val" "lt"; then
                min_val="${PAYOFFS[$a,$s]}"
            fi
        done

        if bc_compare "$min_val" "$max_min" "gt"; then
            max_min=$min_val
            best_idx=$a
        fi
    done

    echo "${ALT_NAMES[$best_idx]}"
}

__get_savage_result() {
    local alt_count=${#ALT_NAMES[@]}
    local state_count=${#STATE_NAMES[@]}

    # Максимумы по столбцам
    declare -a column_max
    for ((s=0; s<state_count; s++)); do
        column_max[$s]="${PAYOFFS[0,$s]}"
        for ((a=1; a<alt_count; a++)); do
            if bc_compare "${PAYOFFS[$a,$s]}" "${column_max[$s]}" "gt"; then
                column_max[$s]="${PAYOFFS[$a,$s]}"
            fi
        done
    done

    local min_max_regret=999999
    local best_idx=0

    for ((a=0; a<alt_count; a++)); do
        local max_regret=0
        for ((s=0; s<state_count; s++)); do
            local regret=$(bc_calc "${column_max[$s]} - ${PAYOFFS[$a,$s]}")
            if bc_compare "$regret" "$max_regret" "gt"; then
                max_regret=$regret
            fi
        done

        if bc_compare "$max_regret" "$min_max_regret" "lt"; then
            min_max_regret=$max_regret
            best_idx=$a
        fi
    done

    echo "${ALT_NAMES[$best_idx]}"
}

__get_hurwitz_result() {
    local alt_count=${#ALT_NAMES[@]}
    local state_count=${#STATE_NAMES[@]}

    local max_val=-999999
    local best_idx=0

    for ((a=0; a<alt_count; a++)); do
        local min_val="${PAYOFFS[$a,0]}"
        local max_val_local="${PAYOFFS[$a,0]}"

        for ((s=1; s<state_count; s++)); do
            local val="${PAYOFFS[$a,$s]}"
            if bc_compare "$val" "$min_val" "lt"; then
                min_val=$val
            fi
            if bc_compare "$val" "$max_val_local" "gt"; then
                max_val_local=$val
            fi
        done

        local hurwitz=$(bc_calc "$CURRENT_ALPHA_HURWITZ * $max_val_local + (1 - $CURRENT_ALPHA_HURWITZ) * $min_val")

        if bc_compare "$hurwitz" "$max_val" "gt"; then
            max_val=$hurwitz
            best_idx=$a
        fi
    done

    echo "${ALT_NAMES[$best_idx]}"
}

normalize_probabilities() {
    local state_count=${#STATE_NAMES[@]}

    if [ $state_count -eq 0 ]; then
        echo "Ошибка: нет состояний для нормализации вероятностей" >&2
        return 1
    fi

    # Суммируем вероятности
    local prob_sum=0
    local valid_count=0
    for ((s=0; s<state_count; s++)); do
        local prob="${PROBS[$s]:-0}"
        prob_sum=$(bc_calc "$prob_sum + $prob")
        if bc_compare "$prob" "0" "gt"; then
            ((valid_count++))
        fi
    done

    # Случай 1: Нет вероятностей или все нулевые
    if bc_compare "$prob_sum" "0" "eq" || [ $valid_count -eq 0 ]; then
        echo "Внимание: вероятности не заданы или все равны 0" >&2
        echo "Устанавливается равномерное распределение" >&2

        local equal_prob=$(bc_calc "1 / $state_count")
        for ((s=0; s<state_count; s++)); do
            PROBS[$s]=$equal_prob
        done
        return 0
    fi

    # Случай 2: Сумма вероятностей слишком мала
    if bc_compare "$prob_sum" "0.01" "le"; then
        echo "Ошибка: сумма вероятностей слишком мала ($prob_sum)" >&2
        return 1
    fi

    # Случай 3: Нормализация при необходимости
    local diff=$(bc_calc "abs($prob_sum - 1)")
    if bc_compare "$diff" "0.01" "gt"; then
        echo "Нормализую вероятности: сумма была $prob_sum" >&2
        for ((s=0; s<state_count; s++)); do
            PROBS[$s]=$(bc_calc "${PROBS[$s]:-0} / $prob_sum")
        done
    fi

    # Финальная проверка
    local final_sum=0
    for ((s=0; s<state_count; s++)); do
        final_sum=$(bc_calc "$final_sum + ${PROBS[$s]}")
    done

    echo "Нормализация завершена. Сумма вероятностей: $(LANG=C printf "%.3f" "$final_sum")" >&2
    return 0
}

# === ФОРМАТИРОВАНИЕ ТАБЛИЦ ===
__repeat_char() {
    local n="$1" ch="$2"
    printf "%*s" "$n" "" | tr ' ' "$ch"
}

__table_pick_utf8_ctype() {
    # Подбираем UTF-8 LC_CTYPE для корректного подсчёта длины
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
    # Длина строки в символах (не в байтах).
    local s="$1"
    local ctype
    ctype="$(__table_pick_utf8_ctype)"

    if [[ -n "$ctype" ]]; then
        LC_CTYPE="$ctype" awk '{print length($0)}' <<<"$s"
    else
        # fallback (хуже для кириллицы, но надежнее)
        echo "${#s}"
    fi
}

__fmt_cell() {
    # fmt, value -> formatted string (без \n)
    local fmt="$1" val="$2"
    local out
    out=$(LC_NUMERIC=C printf -- "$fmt" "$val" 2>/dev/null)
    out="${out//$'\n'/}"
    printf '%s' "$out"
}

__is_string_fmt() {
    [[ "$1" == *"s"* ]]
}

__pad_right_u8() {
    # печатает str + пробелы до width (в символах)
    local str="$1" width="$2"
    local len
    len="$(__strlen_u8 "$str")"
    printf "%s" "$str"
    if (( width > len )); then
        printf "%*s" $((width - len)) ""
    fi
}

__pad_left_u8() {
    # печатает пробелы + str до width (в символах)
    local str="$1" width="$2"
    local len
    len="$(__strlen_u8 "$str")"
    if (( width > len )); then
        printf "%*s" $((width - len)) ""
    fi
    printf "%s" "$str"
}

__print_table_flex() {
    # args:
    #   title
    #   ncols
    #   headers (ncols)
    #   fmts    (ncols)
    #   rows...  ("c1|c2|c3|...")
    local title="$1"; shift
    local ncols="$1"; shift

    local -a headers fmts rows
    local i row

    for ((i=0; i<ncols; i++)); do headers+=("$1"); shift; done
    for ((i=0; i<ncols; i++)); do fmts+=("$1"); shift; done
    rows=("$@")

    # 1) ширины в СИМВОЛАХ (UTF-8), а не ${#...} (байты)
    local -a w
    for ((i=0; i<ncols; i++)); do
        w[$i]=$(__strlen_u8 "${headers[$i]}")
    done

    for row in "${rows[@]}"; do
        local -a cols
        IFS='|' read -r -a cols <<< "$row"

        for ((i=0; i<ncols; i++)); do
            local fcell
            fcell="$(__fmt_cell "${fmts[$i]}" "${cols[$i]:-}")"
            local flen
            flen="$(__strlen_u8 "$fcell")"
            (( flen > w[$i] )) && w[$i]=$flen
        done
    done

    [[ -n "$title" ]] && echo "$title"

    # 2) заголовок (строковые — влево, числовые — вправо)
    if __is_string_fmt "${fmts[0]}"; then
        __pad_right_u8 "${headers[0]}" "${w[0]}"
    else
        __pad_left_u8  "${headers[0]}" "${w[0]}"
    fi

    for ((i=1; i<ncols; i++)); do
        printf " | "
        if __is_string_fmt "${fmts[$i]}"; then
            __pad_right_u8 "${headers[$i]}" "${w[$i]}"
        else
            __pad_left_u8  "${headers[$i]}" "${w[$i]}"
        fi
    done
    echo ""

    # 3) разделитель
    printf "%s" "$(__repeat_char "${w[0]}" '-')"
    for ((i=1; i<ncols; i++)); do
        printf -- "-+-%s" "$(__repeat_char "${w[$i]}" '-')"
    done
    echo ""

    # 4) строки
    for row in "${rows[@]}"; do
        local -a cols
        IFS='|' read -r -a cols <<< "$row"

        local c0
        c0="$(__fmt_cell "${fmts[0]}" "${cols[0]:-}")"
        if __is_string_fmt "${fmts[0]}"; then
            __pad_right_u8 "$c0" "${w[0]}"
        else
            __pad_left_u8  "$c0" "${w[0]}"
        fi

        for ((i=1; i<ncols; i++)); do
            printf " | "
            local ci
            ci="$(__fmt_cell "${fmts[$i]}" "${cols[$i]:-}")"
            if __is_string_fmt "${fmts[$i]}"; then
                __pad_right_u8 "$ci" "${w[$i]}"
            else
                __pad_left_u8  "$ci" "${w[$i]}"
            fi
        done
        echo ""
    done

    echo ""
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
    zenity_progress_stop 2>/dev/null
    bc_cleanup 2>/dev/null

    ALT_NAMES=()
    STATE_NAMES=()

    unset PAYOFFS 2>/dev/null; declare -gA PAYOFFS
    unset PROBS 2>/dev/null; declare -gA PROBS

    CURRENT_KNOWN_STATE=""
    CURRENT_ALPHA_HURWITZ=""

    [[ -n "${PROGRESS_FILE-}" && -f "${PROGRESS_FILE-}" ]] && rm -f "$PROGRESS_FILE" 2>/dev/null
    unset PROGRESS_FILE PROGRESS_PID 2>/dev/null

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
    [[ -z "$template" ]] && { echo "Ошибка: пустой шаблон для импорта" >&2; return 1; }

    # Временные структуры
    local -a tmp_alternatives tmp_states
    local -A tmp_payoffs tmp_probs
    local tmp_known_state tmp_alpha_hurwitz
    local tmp_template="$template"

    # Сброс параметров
    local current_section=""
    local line_num=0
    local errors=0

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
                        if ! __check_unique_tmp tmp_alternatives "$item" "альтернативы" "$line_num"; then
                            ((errors++))
                            continue
                        fi
                        tmp_alternatives+=("$item")
                    fi
                done
                ;;

            "Состояния среды"|"Состояния")
                IFS=',' read -ra items <<< "$line"
                for item in "${items[@]}"; do
                    item=$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ -n "$item" ]]; then
                        if ! __check_unique_tmp tmp_states "$item" "состояний" "$line_num"; then
                            ((errors++))
                            continue
                        fi
                        tmp_states+=("$item")
                    fi
                done
                ;;

            "Матрица выигрышей")
                if [[ "$line" =~ ^([^:]+):(.+)$ ]]; then
                    local alt="${BASH_REMATCH[1]}"
                    local values_str="${BASH_REMATCH[2]}"

                    alt=$(echo "$alt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    IFS=',' read -ra values <<< "$values_str"
                    for ((i=0; i<${#values[@]}; i++)); do
                        local val=$(echo "${values[$i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        if [[ "$val" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                            # Найдем индекс альтернативы
                            local alt_idx=-1
                            for ((j=0; j<${#tmp_alternatives[@]}; j++)); do
                                if [ "${tmp_alternatives[$j]}" = "$alt" ]; then
                                    alt_idx=$j
                                    break
                                fi
                            done

                            if [ $alt_idx -ne -1 ]; then
                                tmp_payoffs["$alt_idx,$i"]=$val
                            else
                                echo "Предупреждение: альтернатива '$alt' не объявлена (строка $line_num)" >&2
                            fi
                        fi
                    done
                fi
                ;;

            "Вероятности")
                IFS=',' read -ra items <<< "$line"
                for ((i=0; i<${#items[@]}; i++)); do
                    local prob=$(echo "${items[$i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ "$prob" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                        tmp_probs[$i]=$prob
                    fi
                done
                ;;

            "Параметры")
                if [[ "$line" =~ ^([^=]+)=(.+)$ ]]; then
                    local param="${BASH_REMATCH[1]}"
                    local value="${BASH_REMATCH[2]}"
                    param=$(echo "$param" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    case "$param" in
                        "ИЗВЕСТНОЕ_СОСТОЯНИЕ"|"известное_состояние")
                            tmp_known_state="$value"
                            ;;
                        "АЛЬФА_ГУРВИЦА"|"альфа_гурвица")
                            if [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                                if bc_compare "$value" "0" "ge" && bc_compare "$value" "1" "le"; then
                                    tmp_alpha_hurwitz="$value"
                                else
                                    echo "Ошибка: коэффициент Гурвица вне диапазона 0-1: $value (строка $line_num)" >&2
                                    ((errors++))
                                fi
                            else
                                echo "Ошибка: некорректное значение коэффициента Гурвица: $value (строка $line_num)" >&2
                                ((errors++))
                            fi
                            ;;
                    esac
                fi
                ;;
        esac
    done <<< "$template"

    if [[ $errors -gt 0 ]]; then
        echo "Импорт отменен из-за $errors ошибок" >&2
        return 1
    fi

    # Применение данных
    data_cleanup

    # Копирование данных из временных структур
    ALT_NAMES=("${tmp_alternatives[@]}")
    STATE_NAMES=("${tmp_states[@]}")

    for key in "${!tmp_payoffs[@]}"; do
        PAYOFFS["$key"]="${tmp_payoffs[$key]}"
    done

    for key in "${!tmp_probs[@]}"; do
        PROBS["$key"]="${tmp_probs[$key]}"
    done

    # Установка параметров
    CURRENT_KNOWN_STATE="${tmp_known_state:-${STATE_NAMES[0]}}"
    CURRENT_ALPHA_HURWITZ="${tmp_alpha_hurwitz:-0.65}"

    # Автозаполнение недостающих значений матрицы
    local alt_count=${#ALT_NAMES[@]}
    local state_count=${#STATE_NAMES[@]}
    for ((a=0; a<alt_count; a++)); do
        for ((s=0; s<state_count; s++)); do
            if [ -z "${PAYOFFS[$a,$s]+isset}" ]; then
                PAYOFFS[$a,$s]=0
            fi
        done
    done

    echo "Импорт успешен: ${#ALT_NAMES[@]} альтернатив, ${#STATE_NAMES[@]} состояний" >&2
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
        --title="Редактирование шаблона данных задачи 7" \
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
            --text="Шаблон успешно импортирован!\n\n• Альтернатив: ${#ALT_NAMES[@]}\n• Состояний: ${#STATE_NAMES[@]}" \
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

    if [[ ${#ALT_NAMES[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы альтернативы" >&2
        errors=1
    fi

    if [[ ${#STATE_NAMES[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы состояния среды" >&2
        errors=1
    fi

    local alt_count=${#ALT_NAMES[@]}
    local state_count=${#STATE_NAMES[@]}

    # Проверка матрицы выигрышей
    local expected_count=$((alt_count * state_count))
    local actual_count=0
    for key in "${!PAYOFFS[@]}"; do
        ((actual_count++))
    done

    if [[ $actual_count -lt $expected_count ]]; then
        echo "Предупреждение: в матрице выигрышей заполнено $actual_count из $expected_count ячеек" >&2
        warnings=1
    fi

    # Проверка известного состояния
    if [[ -n "$CURRENT_KNOWN_STATE" ]]; then
        local found=0
        for state in "${STATE_NAMES[@]}"; do
            if [ "$state" = "$CURRENT_KNOWN_STATE" ]; then
                found=1
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            echo "Ошибка: известное состояние '$CURRENT_KNOWN_STATE' не найдено в списке состояний" >&2
            errors=1
        fi
    fi

    # Проверка коэффициента Гурвица
    if ! bc_compare "$CURRENT_ALPHA_HURWITZ" "0" "ge" || ! bc_compare "$CURRENT_ALPHA_HURWITZ" "1" "le"; then
        echo "Ошибка: коэффициент Гурвица должен быть в диапазоне [0, 1]" >&2
        errors=1
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
        subtask1_certainty
        subtask2_risk
        subtask3_uncertainty
        subtask4_conclusions
      )
      ;;
  *) zenity_main_menu ;;
esac
