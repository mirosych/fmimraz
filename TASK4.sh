#!/bin/bash

# === ПЕРЕМЕННЫЕ ===
declare -a ALTERNATIVES CRITERIA STATES
declare -A PAYOFF_3D CRITERIA_WEIGHTS CRITERIA_DIRECTIONS
declare -A STATE_PROBABILITIES INTEGRATED_MATRIX
declare CURRENT_KNOWN_STATE CURRENT_ALPHA_HURWITZ
declare PROGRESS_FILE PROGRESS_PID bcsc=4

# Значения по умолчанию
DEFAULT_KNOWN_STATE="СТАБИЛЬНЫЙ_СЦЕНАРИЙ"
DEFAULT_ALPHA_HURWITZ=0.6

CURRENT_TEMPLATE=""
DEFAULT_TEMPLATE=$(cat <<'EOF'
# ШАБЛОН ДЛЯ ЗАДАЧИ 8: МНОГОКРИТЕРИАЛЬНАЯ НЕОПРЕДЕЛЁННОСТЬ

[Альтернативы]
UBUNTU, FEDORA, ASTRA_LINUX, ALT_LINUX, CALCULATE_LINUX

[Критерии]
БЕЗОПАСНОСТЬ, СТАБИЛЬНОСТЬ, ДОКУМЕНТАЦИЯ, ПОДДЕРЖКА, СТОИМОСТЬ

[Состояния среды]
ГОСУДАРСТВЕННЫЙ_СЕКТОР, КОРПОРАТИВНЫЙ_СЕКТОР, ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР

[Веса критериев]
БЕЗОПАСНОСТЬ:35
СТАБИЛЬНОСТЬ:25
ДОКУМЕНТАЦИЯ:15
ПОДДЕРЖКА:10
СТОИМОСТЬ:15

[Обоснование весов]
БЕЗОПАСНОСТЬ=Максимальный вес (35%), так как в государственных и корпоративных инфраструктурах утечки, компрометация и несоответствие регуляторным требованиям имеют необратимые последствия.
СТАБИЛЬНОСТЬ=Второй по значимости критерий (25%): простои и неконтролируемые изменения в production-средах критичны для любых организаций.
ДОКУМЕНТАЦИЯ=Оценка полноты и доступности знаний о системе (15%): качественная документация и учебные материалы существенно снижают барьер внедрения и сопровождения.
ПОДДЕРЖКА=Включает как официальную коммерческую поддержку, так и зрелость сообщества (10%): важна для снижения операционных рисков, но при сильной внутренней ИТ-команде может частично компенсироваться компетенциями сотрудников.
СТОИМОСТЬ=Совокупные затраты на лицензирование, внедрение и сопровождение (15%): для бизнеса и образования важен TCO, но в долгосрочной перспективе он уступает по значимости безопасности и стабильности.

[Вероятности состояний]
ГОСУДАРСТВЕННЫЙ_СЕКТОР:0.40
КОРПОРАТИВНЫЙ_СЕКТОР:0.35
ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР:0.25

[Направления критериев]
БЕЗОПАСНОСТЬ:максимизация
СТАБИЛЬНОСТЬ:максимизация
ДОКУМЕНТАЦИЯ:максимизация
ПОДДЕРЖКА:максимизация
СТОИМОСТЬ:минимизация

[Параметры]
ИЗВЕСТНОЕ_СОСТОЯНИЕ=ГОСУДАРСТВЕННЫЙ_СЕКТОР
КОЭФФИЦИЕНТ_ГУРВИЦА=0.65
ПОРОГ_РАВЕНСТВА=0.05
ПОРОГ_КВАЗИРАВЕНСТВА=0.5
ГЛАВНЫЙ_КРИТЕРИЙ=БЕЗОПАСНОСТЬ

[Трехмерная матрица]
# Формат: Альтернатива,Состояние,Критерий,Значение
UBUNTU,ГОСУДАРСТВЕННЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,7.0
UBUNTU,ГОСУДАРСТВЕННЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,8.0
UBUNTU,ГОСУДАРСТВЕННЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,8.0
UBUNTU,ГОСУДАРСТВЕННЫЙ_СЕКТОР,ПОДДЕРЖКА,8.0
UBUNTU,ГОСУДАРСТВЕННЫЙ_СЕКТОР,СТОИМОСТЬ,1.0

UBUNTU,КОРПОРАТИВНЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,8.0
UBUNTU,КОРПОРАТИВНЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,8.0
UBUNTU,КОРПОРАТИВНЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,9.0
UBUNTU,КОРПОРАТИВНЫЙ_СЕКТОР,ПОДДЕРЖКА,9.0
UBUNTU,КОРПОРАТИВНЫЙ_СЕКТОР,СТОИМОСТЬ,1.0

UBUNTU,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,8.0
UBUNTU,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,8.0
UBUNTU,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,9.0
UBUNTU,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,ПОДДЕРЖКА,9.0
UBUNTU,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,СТОИМОСТЬ,1.0

FEDORA,ГОСУДАРСТВЕННЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,6.5
FEDORA,ГОСУДАРСТВЕННЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,5.0
FEDORA,ГОСУДАРСТВЕННЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,7.0
FEDORA,ГОСУДАРСТВЕННЫЙ_СЕКТОР,ПОДДЕРЖКА,6.0
FEDORA,ГОСУДАРСТВЕННЫЙ_СЕКТОР,СТОИМОСТЬ,1.0

FEDORA,КОРПОРАТИВНЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,7.0
FEDORA,КОРПОРАТИВНЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,5.0
FEDORA,КОРПОРАТИВНЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,7.5
FEDORA,КОРПОРАТИВНЫЙ_СЕКТОР,ПОДДЕРЖКА,6.5
FEDORA,КОРПОРАТИВНЫЙ_СЕКТОР,СТОИМОСТЬ,1.0

FEDORA,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,7.0
FEDORA,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,6.0
FEDORA,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,8.0
FEDORA,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,ПОДДЕРЖКА,7.0
FEDORA,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,СТОИМОСТЬ,1.0

ASTRA_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,9.0
ASTRA_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,8.5
ASTRA_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,7.0
ASTRA_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,ПОДДЕРЖКА,9.0
ASTRA_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,СТОИМОСТЬ,8.0

ASTRA_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,8.0
ASTRA_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,8.0
ASTRA_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,7.0
ASTRA_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,ПОДДЕРЖКА,8.0
ASTRA_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,СТОИМОСТЬ,8.0

ASTRA_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,8.0
ASTRA_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,7.5
ASTRA_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,6.5
ASTRA_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,ПОДДЕРЖКА,7.0
ASTRA_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,СТОИМОСТЬ,7.5

ALT_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,9.0
ALT_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,8.0
ALT_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,7.0
ALT_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,ПОДДЕРЖКА,7.0
ALT_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,СТОИМОСТЬ,2.0

ALT_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,8.5
ALT_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,8.0
ALT_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,7.0
ALT_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,ПОДДЕРЖКА,7.0
ALT_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,СТОИМОСТЬ,2.0

ALT_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,7.5
ALT_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,7.5
ALT_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,7.0
ALT_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,ПОДДЕРЖКА,7.0
ALT_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,СТОИМОСТЬ,2.0

CALCULATE_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,7.0
CALCULATE_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,8.0
CALCULATE_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,6.0
CALCULATE_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,ПОДДЕРЖКА,6.0
CALCULATE_LINUX,ГОСУДАРСТВЕННЫЙ_СЕКТОР,СТОИМОСТЬ,3.0

CALCULATE_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,7.0
CALCULATE_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,8.0
CALCULATE_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,6.5
CALCULATE_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,ПОДДЕРЖКА,6.5
CALCULATE_LINUX,КОРПОРАТИВНЫЙ_СЕКТОР,СТОИМОСТЬ,3.0

CALCULATE_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,БЕЗОПАСНОСТЬ,7.0
CALCULATE_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,СТАБИЛЬНОСТЬ,8.0
CALCULATE_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,ДОКУМЕНТАЦИЯ,7.0
CALCULATE_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,ПОДДЕРЖКА,6.5
CALCULATE_LINUX,ОБРАЗОВАТЕЛЬНЫЙ_СЕКТОР,СТОИМОСТЬ,3.0
EOF
)

# === ИНТЕРФЕЙС ===
zenity_show_conditions() {
    if ! data_validate; then
        zenity --error --title="Ошибка данных" \
            --text="Данные не загружены или повреждены.\nЗагрузите данные заново." --width=500 2>/dev/null
        return
    fi

    local conditions_text="ЗАДАЧА 8: МНОГОКРИТЕРИАЛЬНЫЙ ВЫБОР В УСЛОВИЯХ НЕОПРЕДЕЛЕННОСТИ

ЦЕЛЬ:
Выбрать оптимальную альтернативу при неопределенности состояний среды и нескольких критериях.

ДВУХЭТАПНЫЙ АНАЛИЗ:
1. Этап 1: Многокритериальная свертка
   - Преобразование 3D-матрицы (альтернативы × состояния × критерии)
     в 2D-матрицу (альтернативы × состояния)
   - Учет весов и направлений критериев

2. Этап 2: Анализ неопределенности интегральных оценок
   - Определенность (известное состояние: $CURRENT_KNOWN_STATE)
   - Риск (критерий Байеса)
   - Полная неопределенность:
     1. Лапласа, 2. Вальда, 3. Сэвиджа, 4. Гурвица (α=$CURRENT_ALPHA_HURWITZ)

ОТЛИЧИЕ ОТ ЗАДАЧИ 7:
Задача 7: одна метрика на ячейку → прямой анализ
Задача 8: вектор критериев → свертка → анализ

ДАННЫЕ:
• Альтернатив: ${#ALTERNATIVES[@]}
• Критериев: ${#CRITERIA[@]}
• Состояний среды: ${#STATES[@]}
• Коэффициент Гурвица: α = $CURRENT_ALPHA_HURWITZ"

    echo "$conditions_text" | zenity --text-info --title="Задача 8" \
        --width=800 --height=600 --font="monospace 10" 2>/dev/null || true
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
            --title="Задача 8: Многокритериальные решения в условиях неопределенности" \
            --text="Выберите действие:" \
            --column="Опция" \
            "▶ Выполнить полный анализ" \
            "1. Показать исходные данные" \
            "2. Выполнить свертку критериев" \
            "3. Анализ определенности" \
            "4. Анализ риска (Байес)" \
            "5. Анализ полной неопределенности" \
            "6. Итоговые выводы" \
            "✏️ Редактировать данные" \
            "📋 Условия задачи" \
            --width=450 --height=550 2>/dev/null)

        if [ -z "$choice" ]; then
            break
        fi

        case "$choice" in
            "▶ Выполнить полный анализ")
                zenity_run_all_tasks
                ;;
            "1. Показать исходные данные")
                { __display_3d_matrix; } | zenity --text-info \
                    --title="Исходные данные" \
                    --width=700 --height=800 --font="monospace 10" 2>/dev/null || __display_3d_matrix
                ;;
            "2. Выполнить свертку критериев")
                { __form_integrated_matrix; } | zenity --text-info \
                    --title="Свертка критериев" \
                    --width=800 --height=800 --font="monospace 10" 2>/dev/null || __form_integrated_matrix
                ;;
            "3. Анализ определенности")
                { __analyze_certainty; } | zenity --text-info \
                    --title="Анализ определенности" \
                    --width=650 --height=500 --font="monospace 10" 2>/dev/null || __analyze_certainty
                ;;
            "4. Анализ риска (Байес)")
                { __analyze_risk; } | zenity --text-info \
                    --title="Анализ риска" \
                    --width=650 --height=800 --font="monospace 10" 2>/dev/null || __analyze_risk
                ;;
            "5. Анализ полной неопределенности")
                { __analyze_uncertainty; } | zenity --text-info \
                    --title="Анализ неопределенности" \
                    --width=800 --height=800 --font="monospace 10" 2>/dev/null || __analyze_uncertainty
                ;;
            "6. Итоговые выводы")
                { __final_recommendation; } | zenity --text-info \
                    --title="Итоговые выводы" \
                    --width=650 --height=550 --font="monospace 10" 2>/dev/null || __final_recommendation
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

    zenity_progress_start "Решение задачи 8" "Подготовка данных..."

    {
        echo "=== РЕШЕНИЕ ЗАДАЧИ 8 ==="
        echo ""

        echo "10" >&3
        echo "# 1. Отображение исходных данных..." >&3
        __display_3d_matrix

        echo "30" >&3
        echo "# 2. Свертка критериев..." >&3
        __form_integrated_matrix

        echo "50" >&3
        echo "# 3. Анализ определенности..." >&3
        __analyze_certainty

        echo "65" >&3
        echo "# 4. Анализ риска..." >&3
        __analyze_risk

        echo "80" >&3
        echo "# 5. Анализ неопределенности..." >&3
        __analyze_uncertainty

        echo "95" >&3
        echo "# 6. Итоговые выводы..." >&3
        __final_recommendation

        echo "100" >&3
        echo "# Вычисления завершены" >&3
        sleep 0.5

    } > "$temp_file" 2>&1

    zenity_progress_stop

    cat "$temp_file" | zenity --text-info \
        --title="Решение задачи 8" \
        --width=900 --height=1000 \
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
__display_3d_matrix() {
    echo "ИСХОДНЫЕ ДАННЫЕ: ТРЁХМЕРНАЯ МАТРИЦА"
    echo "===================================="
    echo ""

    echo "Структура задачи:"
    echo "  Альтернативы: ${ALTERNATIVES[*]}"
    echo "  Критерии: ${CRITERIA[*]}"
    echo "  Состояния: ${STATES[*]}"
    echo ""

    echo "Веса критериев:"
    for crit in "${CRITERIA[@]}"; do
        local weight_raw="${CRITERIA_WEIGHTS[$crit]:-0}"
        local weight; weight=$(normalize_number "$weight_raw")
        local direction="${CRITERIA_DIRECTIONS[$crit]:-максимизация}"
        local dirshort="max"; [[ "$direction" == "минимизация" ]] && dirshort="min"
        LC_NUMERIC=C printf "  %-18s  %5.1f%%  (%s)\n" "$crit" "$weight" "$dirshort"
    done
    echo ""

    echo "Вероятности состояний:"
    for state in "${STATES[@]}"; do
        local p_raw="${STATE_PROBABILITIES[$state]:-0}"
        local p; p=$(normalize_number "$p_raw")
        LC_NUMERIC=C printf "  %-25s  %.3f\n" "$state" "$p"
    done
    echo ""

    # Матрица по каждому состоянию — в виде ровной таблицы
    for state in "${STATES[@]}"; do
        echo "Состояние: $state"

        local -a headers=("Альтернатива")
        local -a fmts=("%s")
        for crit in "${CRITERIA[@]}"; do
            headers+=("$crit")
            fmts+=("%0.4f")
        done

        local -a rows=()
        for alt in "${ALTERNATIVES[@]}"; do
            local row="$alt"
            for crit in "${CRITERIA[@]}"; do
                local v_raw="${PAYOFF_3D[$alt,$state,$crit]:-0}"
                local v; v=$(normalize_number "$v_raw")
                row="$row|$v"
            done
            rows+=("$row")
        done

        __print_table_flex "" "$((${#headers[@]}))" \
            "${headers[@]}" \
            "${fmts[@]}" \
            "${rows[@]}"
    done
}

__form_integrated_matrix() {
    echo "ЭТАП 1: СВЁРТКА КРИТЕРИЕВ (3D → 2D)"
    echo "===================================="
    echo ""

    unset INTEGRATED_MATRIX 2>/dev/null
    declare -gA INTEGRATED_MATRIX

    for state in "${STATES[@]}"; do
        echo "Состояние: $state"
        echo ""

        # min/max по критериям в данном состоянии
        declare -A minvals maxvals
        for crit in "${CRITERIA[@]}"; do
            local minval="999999"
            local maxval="-999999"

            for alt in "${ALTERNATIVES[@]}"; do
                local val_raw="${PAYOFF_3D[$alt,$state,$crit]:-0}"
                local val; val=$(normalize_number "$val_raw")
                if bc_compare "$val" "$minval" lt; then minval="$val"; fi
                if bc_compare "$val" "$maxval" gt; then maxval="$val"; fi
            done

            minvals["$crit"]="$minval"
            maxvals["$crit"]="$maxval"
        done

        # расчёт интегральной оценки
        for alt in "${ALTERNATIVES[@]}"; do
            local integratedscore="0"

            echo "  $alt:"
            for crit in "${CRITERIA[@]}"; do
                local val; val=$(normalize_number "${PAYOFF_3D[$alt,$state,$crit]:-0}")

                local minval maxval weight direction
                minval=$(normalize_number "${minvals[$crit]}")
                maxval=$(normalize_number "${maxvals[$crit]}")
                weight=$(normalize_number "${CRITERIA_WEIGHTS[$crit]:-0}")
                direction="${CRITERIA_DIRECTIONS[$crit]:-максимизация}"

                local normalizedval="0"
                local denominator; denominator=$(bc_calc "$maxval - $minval")

                if bc_compare "$denominator" "0" gt; then
                    if [[ "$direction" == "минимизация" ]]; then
                        normalizedval=$(bc_calc "($maxval - $val) / $denominator")
                    else
                        normalizedval=$(bc_calc "($val - $minval) / $denominator")
                    fi
                else
                    normalizedval="0.5"
                fi
                normalizedval=$(normalize_number "$normalizedval")

                local contribution
                contribution=$(bc_calc "$normalizedval * $weight / 100")
                contribution=$(normalize_number "$contribution")

                integratedscore=$(bc_calc "$integratedscore + $contribution")
                integratedscore=$(normalize_number "$integratedscore")

                LC_NUMERIC=C printf "    %-14s %7.4f → %6.4f × %5.1f%% = %7.4f\n" \
                    "$crit" "$val" "$normalizedval" "$weight" "$contribution"
            done

            INTEGRATED_MATRIX["$alt,$state"]="$(normalize_number "$integratedscore")"
            LC_NUMERIC=C printf "    Итого: %7.4f\n" "$(normalize_number "$integratedscore")"
            echo ""
        done
    done

    echo "Интегральная матрица (альтернативы × состояния):"

    local -a headers=("Альтернатива")
    local -a fmts=("%s")
    for state in "${STATES[@]}"; do
        headers+=("$state")
        fmts+=("%0.4f")
    done

    local -a rows=()
    for alt in "${ALTERNATIVES[@]}"; do
        local row="$alt"
        for state in "${STATES[@]}"; do
            row="$row|$(normalize_number "${INTEGRATED_MATRIX[$alt,$state]:-0}")"
        done
        rows+=("$row")
    done

    __print_table_flex "" "$((${#headers[@]}))" \
        "${headers[@]}" \
        "${fmts[@]}" \
        "${rows[@]}"
}

__analyze_certainty() {
    echo "ЭТАП 2.1: АНАЛИЗ ОПРЕДЕЛЁННОСТИ"
    echo "==============================="
    echo ""
    echo "Известное состояние: $CURRENT_KNOWN_STATE"
    echo ""

    if [[ ${#INTEGRATED_MATRIX[@]} -eq 0 ]]; then
        echo "Предупреждение: интегральная матрица не рассчитана, выполняю свёртку..."
        __form_integrated_matrix >/dev/null
    fi

    declare -A scores
    local bestscore="-999999"
    local bestalt=""

    for alt in "${ALTERNATIVES[@]}"; do
        local score; score=$(normalize_number "${INTEGRATED_MATRIX[$alt,$CURRENT_KNOWN_STATE]:-0}")
        scores["$alt"]="$score"
        if bc_compare "$score" "$bestscore" gt; then
            bestscore="$score"
            bestalt="$alt"
        fi
    done

    local -a rows=()
    for alt in "${ALTERNATIVES[@]}"; do
        local mark=""
        [[ "$alt" == "$bestalt" ]] && mark="оптимум"
        rows+=( "$alt|${scores[$alt]}|$mark" )
    done

    __print_table_flex "Оценки в состоянии '$CURRENT_KNOWN_STATE':" 3 \
        "Альтернатива" "Оценка" "Примечание" \
        "%s" "%0.4f" "%s" \
        "${rows[@]}"

    echo "РЕЗУЛЬТАТ:"
    echo "Оптимальная альтернатива: $bestalt"
    LC_NUMERIC=C printf "Максимальная оценка: %.4f\n" "$(normalize_number "$bestscore")"
    echo ""
}

__analyze_risk() {
    echo "ЭТАП 2.2: АНАЛИЗ РИСКА (КРИТЕРИЙ БАЙЕСА)"
    echo "========================================"
    echo ""

    if [[ ${#INTEGRATED_MATRIX[@]} -eq 0 ]]; then
        echo "Предупреждение: интегральная матрица не рассчитана, выполняю свёртку..."
        __form_integrated_matrix >/dev/null
    fi

    echo "Вероятности состояний:"
    for state in "${STATES[@]}"; do
        local p; p=$(normalize_number "${STATE_PROBABILITIES[$state]:-0}")
        LC_NUMERIC=C printf "  %-25s  %.3f\n" "$state" "$p"
    done
    echo ""

    declare -A expectations
    local bestexpected="-999999"
    local bestalt=""

    echo "Расчёт математического ожидания (EMV):"
    echo ""

    for alt in "${ALTERNATIVES[@]}"; do
        local expected="0"

        # небольшой "разворот" формулы на строках
        echo "  $alt:"
        for state in "${STATES[@]}"; do
            local prob score term
            prob=$(normalize_number "${STATE_PROBABILITIES[$state]:-0}")
            score=$(normalize_number "${INTEGRATED_MATRIX[$alt,$state]:-0}")
            term=$(bc_calc "$score * $prob")
            expected=$(bc_calc "$expected + $term")

            term=$(normalize_number "$term")
            LC_NUMERIC=C printf "    %-25s  %.4f × %.3f = %.4f\n" "$state" "$score" "$prob" "$term"
        done

        expected=$(normalize_number "$expected")
        expectations["$alt"]="$expected"
        LC_NUMERIC=C printf "    EMV = %.4f\n" "$expected"
        echo ""

        if bc_compare "$expected" "$bestexpected" gt; then
            bestexpected="$expected"
            bestalt="$alt"
        fi
    done

    local -a rows=()
    for alt in "${ALTERNATIVES[@]}"; do
        local mark=""
        [[ "$alt" == "$bestalt" ]] && mark="оптимум"
        rows+=( "$alt|${expectations[$alt]}|$mark" )
    done

    __print_table_flex "Итог по Байесу:" 3 \
        "Альтернатива" "EMV" "Примечание" \
        "%s" "%0.4f" "%s" \
        "${rows[@]}"

    echo "РЕЗУЛЬТАТ:"
    echo "Оптимальная альтернатива: $bestalt"
    LC_NUMERIC=C printf "Максимальное EMV: %.4f\n" "$(normalize_number "$bestexpected")"
    echo ""
}

__analyze_uncertainty() {
    echo "ЭТАП 2.3: АНАЛИЗ ПОЛНОЙ НЕОПРЕДЕЛЁННОСТИ"
    echo "========================================="
    echo ""

    if [[ ${#INTEGRATED_MATRIX[@]} -eq 0 ]]; then
        echo "Предупреждение: интегральная матрица не рассчитана, выполняю свёртку..."
        __form_integrated_matrix >/dev/null
    fi

    local state_count=${#STATES[@]}
    local equalprob; equalprob=$(normalize_number "$(bc_calc "1 / $state_count")")

    # 1) Лаплас
    echo "1) Критерий Лапласа (равные вероятности)"
    LC_NUMERIC=C printf "   1/%d = %.4f\n\n" "$state_count" "$equalprob"

    declare -A laplacevalues laplacesums
    local bestlaplacescore="-999999" bestlaplace=""

    for alt in "${ALTERNATIVES[@]}"; do
        local sum="0"
        for state in "${STATES[@]}"; do
            local score; score=$(normalize_number "${INTEGRATED_MATRIX[$alt,$state]:-0}")
            sum=$(bc_calc "$sum + $score")
        done
        sum=$(normalize_number "$sum")
        laplacesums["$alt"]="$sum"

        local laplace; laplace=$(normalize_number "$(bc_calc "$sum * $equalprob")")
        laplacevalues["$alt"]="$laplace"

        if bc_compare "$laplace" "$bestlaplacescore" gt; then
            bestlaplacescore="$laplace"
            bestlaplace="$alt"
        fi
    done

    local -a rows=()
    for alt in "${ALTERNATIVES[@]}"; do
        local mark=""
        [[ "$alt" == "$bestlaplace" ]] && mark="оптимум"
        rows+=( "$alt|${laplacevalues[$alt]}|$mark" )
    done

    __print_table_flex "" 3 \
        "Альтернатива" "Лаплас" "Примечание" \
        "%s" "%0.4f" "%s" \
        "${rows[@]}"

    # 2) Вальд (максимин)
    echo "2) Критерий Вальда (максимин)"
    echo ""

    declare -A minvalues
    local bestwaldscore="-999999" bestwald=""

    for alt in "${ALTERNATIVES[@]}"; do
        local minval="1000000"
        for state in "${STATES[@]}"; do
            local score; score=$(normalize_number "${INTEGRATED_MATRIX[$alt,$state]:-0}")
            if bc_compare "$score" "$minval" lt; then minval="$score"; fi
        done
        minval=$(normalize_number "$minval")
        minvalues["$alt"]="$minval"

        if bc_compare "$minval" "$bestwaldscore" gt; then
            bestwaldscore="$minval"
            bestwald="$alt"
        fi
    done

    rows=()
    for alt in "${ALTERNATIVES[@]}"; do
        local mark=""
        [[ "$alt" == "$bestwald" ]] && mark="оптимум"
        rows+=( "$alt|${minvalues[$alt]}|$mark" )
    done

    __print_table_flex "" 3 \
        "Альтернатива" "Вальд (min)" "Примечание" \
        "%s" "%0.4f" "%s" \
        "${rows[@]}"

    # 3) Сэвидж (минимакс сожаления)
    echo "3) Критерий Сэвиджа (минимакс риска)"
    echo ""

    declare -A maxinstate
    for state in "${STATES[@]}"; do
        local maxval="-1000000"
        for alt in "${ALTERNATIVES[@]}"; do
            local score; score=$(normalize_number "${INTEGRATED_MATRIX[$alt,$state]:-0}")
            if bc_compare "$score" "$maxval" gt; then maxval="$score"; fi
        done
        maxinstate["$state"]=$(normalize_number "$maxval")
    done

    echo "Максимумы по состояниям:"
    local -a mxrows=()
    for state in "${STATES[@]}"; do
        mxrows+=( "$state|${maxinstate[$state]}" )
    done
    __print_table_flex "" 2 \
        "Состояние" "max" \
        "%s" "%0.4f" \
        "${mxrows[@]}"

    declare -A maxregrets
    local bestsavagescore="999999" bestsavage=""

    for alt in "${ALTERNATIVES[@]}"; do
        local maxregret="0"
        for state in "${STATES[@]}"; do
            local score mx regret
            score=$(normalize_number "${INTEGRATED_MATRIX[$alt,$state]:-0}")
            mx=$(normalize_number "${maxinstate[$state]}")
            regret=$(normalize_number "$(bc_calc "$mx - $score")")
            if bc_compare "$regret" "$maxregret" gt; then maxregret="$regret"; fi
        done

        maxregret=$(normalize_number "$maxregret")
        maxregrets["$alt"]="$maxregret"

        if bc_compare "$maxregret" "$bestsavagescore" lt; then
            bestsavagescore="$maxregret"
            bestsavage="$alt"
        fi
    done

    rows=()
    for alt in "${ALTERNATIVES[@]}"; do
        local mark=""
        [[ "$alt" == "$bestsavage" ]] && mark="оптимум"
        rows+=( "$alt|${maxregrets[$alt]}|$mark" )
    done

    __print_table_flex "" 3 \
        "Альтернатива" "Сэвидж (max риск)" "Примечание" \
        "%s" "%0.4f" "%s" \
        "${rows[@]}"

    # 4) Гурвиц
    echo "4) Критерий Гурвица"
    echo ""

    local a; a=$(normalize_number "$CURRENT_ALPHA_HURWITZ")
    LC_NUMERIC=C printf "α = %.4f\n\n" "$a"

    declare -A hurwitzvalues minvalshurwitz maxvalshurwitz
    local besthurwitzscore="-999999" besthurwitz=""

    for alt in "${ALTERNATIVES[@]}"; do
        local minval="1000000" maxval="-1000000"

        for state in "${STATES[@]}"; do
            local score; score=$(normalize_number "${INTEGRATED_MATRIX[$alt,$state]:-0}")
            if bc_compare "$score" "$minval" lt; then minval="$score"; fi
            if bc_compare "$score" "$maxval" gt; then maxval="$score"; fi
        done

        minval=$(normalize_number "$minval")
        maxval=$(normalize_number "$maxval")
        minvalshurwitz["$alt"]="$minval"
        maxvalshurwitz["$alt"]="$maxval"

        local hurwitz
        hurwitz=$(bc_calc "$a * $maxval + (1 - $a) * $minval")
        hurwitz=$(normalize_number "$hurwitz")
        hurwitzvalues["$alt"]="$hurwitz"

        if bc_compare "$hurwitz" "$besthurwitzscore" gt; then
            besthurwitzscore="$hurwitz"
            besthurwitz="$alt"
        fi
    done

    rows=()
    for alt in "${ALTERNATIVES[@]}"; do
        local mark=""
        [[ "$alt" == "$besthurwitz" ]] && mark="оптимум"
        rows+=( "$alt|${minvalshurwitz[$alt]}|${maxvalshurwitz[$alt]}|${hurwitzvalues[$alt]}|$mark" )
    done

    __print_table_flex "" 5 \
        "Альтернатива" "min" "max" "Гурвиц" "Примечание" \
        "%s" "%0.4f" "%0.4f" "%0.4f" "%s" \
        "${rows[@]}"

    # Сводная таблица
    echo "СВОДНАЯ ТАБЛИЦА:"
    rows=()
    for alt in "${ALTERNATIVES[@]}"; do
        local note=""
        [[ "$alt" == "$bestlaplace"  ]] && note="${note}Лаплас, "
        [[ "$alt" == "$bestwald"     ]] && note="${note}Вальд, "
        [[ "$alt" == "$bestsavage"   ]] && note="${note}Сэвидж, "
        [[ "$alt" == "$besthurwitz"  ]] && note="${note}Гурвиц, "
        note="${note%, }"

        rows+=( "$alt|${laplacevalues[$alt]}|${minvalues[$alt]}|${maxregrets[$alt]}|${hurwitzvalues[$alt]}|$note" )
    done

    __print_table_flex "" 6 \
        "Альтернатива" "Лаплас" "Вальд" "Сэвидж" "Гурвиц" "Оптимум по" \
        "%s" "%0.4f" "%0.4f" "%0.4f" "%0.4f" "%s" \
        "${rows[@]}"
}

__final_recommendation() {
    echo "ИТОГОВЫЕ ВЫВОДЫ"
    echo "==============="
    echo ""

    if [[ ${#INTEGRATED_MATRIX[@]} -eq 0 ]]; then
        echo "Предупреждение: интегральная матрица не рассчитана, выполняю свёртку..."
        __form_integrated_matrix >/dev/null
    fi

    declare -A votes

    # Список методов и их победителей
    local -a methods_rows=()

    local r

    r=$(__get_certainty_result)
    [[ -n "$r" ]] && votes["$r"]=$(( ${votes["$r"]:-0} + 1 ))
    methods_rows+=( "Определённость|$r" )

    r=$(__get_risk_result)
    [[ -n "$r" ]] && votes["$r"]=$(( ${votes["$r"]:-0} + 1 ))
    methods_rows+=( "Риск (Байес)|$r" )

    r=$(__get_laplace_result)
    [[ -n "$r" ]] && votes["$r"]=$(( ${votes["$r"]:-0} + 1 ))
    methods_rows+=( "Лаплас|$r" )

    r=$(__get_wald_result)
    [[ -n "$r" ]] && votes["$r"]=$(( ${votes["$r"]:-0} + 1 ))
    methods_rows+=( "Вальд|$r" )

    r=$(__get_savage_result)
    [[ -n "$r" ]] && votes["$r"]=$(( ${votes["$r"]:-0} + 1 ))
    methods_rows+=( "Сэвидж|$r" )

    r=$(__get_hurwitz_result)
    [[ -n "$r" ]] && votes["$r"]=$(( ${votes["$r"]:-0} + 1 ))
    methods_rows+=( "Гурвиц|$r" )

    __print_table_flex "Оптимальные альтернативы по методам:" 2 \
        "Метод" "Победитель" \
        "%s" "%s" \
        "${methods_rows[@]}"

    # Голосование
    local maxvotes=0
    local -a vote_rows=()
    for alt in "${ALTERNATIVES[@]}"; do
        local v=${votes["$alt"]:-0}
        (( v > maxvotes )) && maxvotes=$v
        vote_rows+=( "$alt|$v" )
    done

    __print_table_flex "Голосование методов (сколько раз альтернатива стала лучшей):" 2 \
        "Альтернатива" "Голосов" \
        "%s" "%d" \
        "${vote_rows[@]}"

    # Лидеры
    local -a leaders=()
    for alt in "${ALTERNATIVES[@]}"; do
        [[ ${votes["$alt"]:-0} -eq $maxvotes ]] && leaders+=("$alt")
    done

    if [[ $maxvotes -eq 0 ]]; then
        echo "Итог: не удалось определить лидера (нет результатов методов)."
        return 0
    fi

    if [[ ${#leaders[@]} -eq 1 ]]; then
        echo "ИТОГОВАЯ РЕКОМЕНДАЦИЯ: ${leaders[0]}"
        echo "Количество побед: $maxvotes из 6 методов"
        return 0
    fi

    echo "Ничья между: ${leaders[*]} (побед: $maxvotes)"
    echo ""
    echo "Доп. разбор: средняя интегральная оценка по всем состояниям для лидеров:"

    local -a avg_rows=()
    for alt in "${leaders[@]}"; do
        local totalscore="0"
        for state in "${STATES[@]}"; do
            local score; score=$(normalize_number "${INTEGRATED_MATRIX[$alt,$state]:-0}")
            totalscore=$(bc_calc "$totalscore + $score")
        done
        local avgscore
        avgscore=$(normalize_number "$(bc_calc "$totalscore / ${#STATES[@]}")")
        avg_rows+=( "$alt|$avgscore" )
    done

    __print_table_flex "" 2 \
        "Альтернатива" "Средняя оценка" \
        "%s" "%0.4f" \
        "${avg_rows[@]}"
}

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ АНАЛИЗА ===
__get_certainty_result() {
    local best_alt="" best_score=-1

    for alt in "${ALTERNATIVES[@]}"; do
        local key="$alt,$CURRENT_KNOWN_STATE"
        local score="${INTEGRATED_MATRIX[$key]:-0}"
        if bc_compare "$score" "$best_score" "gt"; then
            best_score="$score"
            best_alt="$alt"
        fi
    done

    echo "$best_alt"
}

__get_risk_result() {
    local best_alt="" best_expected=-1

    for alt in "${ALTERNATIVES[@]}"; do
        local expected=0
        for state in "${STATES[@]}"; do
            local prob="${STATE_PROBABILITIES[$state]}"
            local key="$alt,$state"
            local score="${INTEGRATED_MATRIX[$key]:-0}"
            expected=$(bc_calc "$expected + $score * $prob")
        done

        if bc_compare "$expected" "$best_expected" "gt"; then
            best_expected="$expected"
            best_alt="$alt"
        fi
    done

    echo "$best_alt"
}

__get_laplace_result() {
    local state_count=${#STATES[@]}
    local equal_prob=$(bc_calc "1 / $state_count")
    local best_laplace_score=-999999
    local best_laplace="не определено"

    for alt in "${ALTERNATIVES[@]}"; do
        local sum=0
        for state in "${STATES[@]}"; do
            local key="$alt,$state"
            sum=$(bc_calc "$sum + ${INTEGRATED_MATRIX[$key]:-0}")
        done
        local laplace=$(bc_calc "$sum * $equal_prob")

        if bc_compare "$laplace" "$best_laplace_score" "gt"; then
            best_laplace_score="$laplace"
            best_laplace="$alt"
        fi
    done

    echo "$best_laplace"
}

__get_wald_result() {
    local best_alt="" best_min_score=-1

    for alt in "${ALTERNATIVES[@]}"; do
        local min_score=1000000
        for state in "${STATES[@]}"; do
            local key="$alt,$state"
            local score="${INTEGRATED_MATRIX[$key]:-0}"
            if bc_compare "$score" "$min_score" "lt"; then
                min_score="$score"
            fi
        done

        if bc_compare "$min_score" "$best_min_score" "gt"; then
            best_min_score="$min_score"
            best_alt="$alt"
        fi
    done

    echo "$best_alt"
}

__get_savage_result() {
    # Находим максимумы по состояниям
    declare -A max_in_state
    for state in "${STATES[@]}"; do
        local max_val=-1000000
        for alt in "${ALTERNATIVES[@]}"; do
            local key="$alt,$state"
            local score="${INTEGRATED_MATRIX[$key]:-0}"
            if bc_compare "$score" "$max_val" "gt"; then
                max_val="$score"
            fi
        done
        max_in_state[$state]="$max_val"
    done

    local best_alt="" best_max_regret=1000000

    for alt in "${ALTERNATIVES[@]}"; do
        local max_regret=0
        for state in "${STATES[@]}"; do
            local key="$alt,$state"
            local score="${INTEGRATED_MATRIX[$key]:-0}"
            local regret=$(bc_calc "${max_in_state[$state]} - $score")
            if bc_compare "$regret" "$max_regret" "gt"; then
                max_regret="$regret"
            fi
        done

        if bc_compare "$max_regret" "$best_max_regret" "lt"; then
            best_max_regret="$max_regret"
            best_alt="$alt"
        fi
    done

    echo "$best_alt"
}

__get_hurwitz_result() {
    local best_alt="" best_hurwitz=-1

    for alt in "${ALTERNATIVES[@]}"; do
        local min_score=1000000
        local max_score=-1000000

        for state in "${STATES[@]}"; do
            local key="$alt,$state"
            local score="${INTEGRATED_MATRIX[$key]:-0}"
            if bc_compare "$score" "$min_score" "lt"; then
                min_score="$score"
            fi
            if bc_compare "$score" "$max_score" "gt"; then
                max_score="$score"
            fi
        done

        local hurwitz=$(bc_calc "$CURRENT_ALPHA_HURWITZ * $max_score + (1 - $CURRENT_ALPHA_HURWITZ) * $min_score")

        if bc_compare "$hurwitz" "$best_hurwitz" "gt"; then
            best_hurwitz="$hurwitz"
            best_alt="$alt"
        fi
    done

    echo "$best_alt"
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

    # Если вообще нет UTF-8 локалей — вернём пусто
    printf '%s' ""
}

__strlen_u8() {
    # Длина строки в символах (не в байтах).
    local s="$1"
    local ctype
    ctype="$(__table_pick_utf8_ctype)"

    if [[ -n "$ctype" ]]; then
        LC_CTYPE="$ctype" awk -v s="$s" 'BEGIN{print length(s)}'
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
            fcell="$(__fmt_cell "${fmts[$i]}" "${cols[$i]}")"
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
        c0="$(__fmt_cell "${fmts[0]}" "${cols[0]}")"
        if __is_string_fmt "${fmts[0]}"; then
            __pad_right_u8 "$c0" "${w[0]}"
        else
            __pad_left_u8  "$c0" "${w[0]}"
        fi

        for ((i=1; i<ncols; i++)); do
            printf " | "
            local ci
            ci="$(__fmt_cell "${fmts[$i]}" "${cols[$i]}")"
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

    BC_INPUT=$(mktemp -u)
    BC_OUTPUT=$(mktemp -u)

    mkfifo "$BC_INPUT" 2>/dev/null
    mkfifo "$BC_OUTPUT" 2>/dev/null

    bc -l < "$BC_INPUT" > "$BC_OUTPUT" 2>/dev/null &
    BC_PROC_PID=$!

    exec 5>"$BC_INPUT"
    exec 6<"$BC_OUTPUT"

    sleep 0.1
}

bc_write() {
    [[ -z "$BC_PROC_PID" ]] && bc_init
    [[ -z "$BC_PROC_PID" ]] && return 1

    echo "$1" >&5 2>/dev/null || {
        bc_cleanup
        bc_init
        echo "$1" >&5 2>/dev/null
    }
}

bc_read() {
    [[ -z "$BC_PROC_PID" ]] && { echo "0"; return 1; }

    local result
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

    # Нормализуем все числа в выражении
    expression=$(echo "$expression" | sed -E 's/(^|[^0-9])\./\10./g')
    expression=$(echo "$expression" | tr ',' '.' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    bc_write "scale=$scale; $expression"
    local result
    result=$(bc_read)

    # Если результат пустой или содержит ошибку, возвращаем значение по умолчанию
    if [[ -z "$result" || "$result" == *"error"* ]]; then
        echo "$default"
        return
    fi

    local out
    out=$(LANG=C printf "%.${scale}f" "$result")
    if [[ "$out" == *.* ]]; then
        out=$(echo "$out" | sed -E 's/0+$//; s/\.$//')
    fi
    echo "$out"
}

normalize_number() {
    local num="$1"
    # Заменяем запятые на точки
    num=$(echo "$num" | tr ',' '.')
    # Добавляем ведущий ноль если начинается с точки
    [[ "$num" =~ ^\. ]] && num="0$num"
    # Убираем лишние пробелы
    num=$(echo "$num" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "$num"
}

bc_compare() {
    local a=$(normalize_number "$1")
    local b=$(normalize_number "$2")
    local op="$3"
    local epsilon=0.000001

    # добавляем ноль к числам с ведущей точкой
    # Если строка начинается с точки, добавляем 0 перед ней
    [[ "$a" =~ ^\. ]] && a="0$a"
    [[ "$b" =~ ^\. ]] && b="0$b"

    # Также заменяем запятые на точки (если есть)
    a=$(echo "$a" | tr ',' '.')
    b=$(echo "$b" | tr ',' '.')

    case "$op" in
        gt)
            bc_write "$a - $b > $epsilon"
            [[ "$(bc_read)" == "1" ]]
            ;;
        lt)
            bc_write "$b - $a > $epsilon"
            [[ "$(bc_read)" == "1" ]]
            ;;
        ge)
            bc_write "$a - $b >= -$epsilon"
            [[ "$(bc_read)" == "1" ]]
            ;;
        le)
            bc_write "$b - $a >= -$epsilon"
            [[ "$(bc_read)" == "1" ]]
            ;;
        eq)
            bc_write "abs($a - $b) < $epsilon"
            [[ "$(bc_read)" == "1" ]]
            ;;
        *)
            echo "Ошибка: неизвестная операция '$op'" >&2
            return 1
            ;;
    esac
}

bc_cleanup() {
    [[ -z "$BC_PROC_PID" ]] && return

    exec 5>&- 2>/dev/null
    exec 6<&- 2>/dev/null

    kill "$BC_PROC_PID" 2>/dev/null
    wait "$BC_PROC_PID" 2>/dev/null 2>&1 || true

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
    CRITERIA=()
    STATES=()

    # Очистка ассоциативных массивов
    unset PAYOFF_3D 2>/dev/null; declare -gA PAYOFF_3D
    unset CRITERIA_WEIGHTS 2>/dev/null; declare -gA CRITERIA_WEIGHTS
    unset CRITERIA_JUSTIFICATION 2>/dev/null; declare -gA CRITERIA_JUSTIFICATION
    unset STATE_PROBABILITIES 2>/dev/null; declare -gA STATE_PROBABILITIES
    unset CRITERIA_DIRECTIONS 2>/dev/null; declare -gA CRITERIA_DIRECTIONS
    unset INTEGRATED_MATRIX 2>/dev/null; declare -gA INTEGRATED_MATRIX
    unset NORMALIZATION_RESULTS 2>/dev/null; declare -gA NORMALIZATION_RESULTS
    unset OPTIMALITY_RESULTS 2>/dev/null; declare -gA OPTIMALITY_RESULTS
    unset UNCERTAINTY_RESULTS 2>/dev/null; declare -gA UNCERTAINTY_RESULTS

    # Сброс скалярных переменных
    CURRENT_KNOWN_STATE="$DEFAULT_KNOWN_STATE"
    CURRENT_ALPHA_HURWITZ="$DEFAULT_ALPHA_HURWITZ"
    EQUALITY_THRESHOLD=""
    QUASI_EQUALITY_THRESHOLD=""
    MAIN_CRITERION_INDEX=""
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
    echo "Загрузка данных для задачи 8 из шаблона по умолчанию..." >&2
    if data_import "$DEFAULT_TEMPLATE"; then
        echo "Данные по умолчанию успешно загружены" >&2
        return 0
    else
        echo "КРИТИЧЕСКАЯ ОШИБКА: Не удалось загрузить шаблон для задачи 8" >&2
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
    local -a tmp_alternatives tmp_criteria tmp_states
    local -A tmp_weights tmp_justifications tmp_probabilities tmp_directions tmp_payoffs
    local tmp_known_state tmp_alpha_hurwitz tmp_equality_threshold tmp_quasiequality_threshold
    local tmp_main_criterion tmp_template="$template"

    # Сброс параметров
    local current_section=""
    local line_num=0
    local errors=0
    local -A seen_alternatives seen_criteria seen_states

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

            "Состояния среды")
                IFS=',' read -ra items <<< "$line"
                for item in "${items[@]}"; do
                    item=$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ -n "$item" ]]; then
                        if ! __check_unique_tmp tmp_states "$item" "состояний среды" "$line_num"; then
                            ((errors++))
                            continue
                        fi
                        tmp_states+=("$item")
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

            "Вероятности состояний")
                if [[ "$line" =~ ^([^:]+):([0-9.]+)$ ]]; then
                    local state="${BASH_REMATCH[1]}"
                    local probability="${BASH_REMATCH[2]}"
                    state=$(echo "$state" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    # Проверка существования состояния
                    if ! __exists_in_array tmp_states "$state"; then
                        echo "Ошибка: состояние '$state' не объявлено (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    # Проверка числового значения
                    if [[ ! "$probability" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                        echo "Ошибка: некорректная вероятность '$probability' (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    tmp_probabilities["$state"]="$probability"
                else
                    echo "Ошибка формата вероятности: '$line' (строка $line_num)" >&2
                    ((errors++))
                fi
                ;;

            "Направления критериев")
                if [[ "$line" =~ ^([^:]+):(максимизация|минимизация)$ ]]; then
                    local crit="${BASH_REMATCH[1]}"
                    local direction="${BASH_REMATCH[2]}"
                    crit=$(echo "$crit" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                    if ! __exists_in_array tmp_criteria "$crit"; then
                        echo "Ошибка: критерий '$crit' не объявлен (строка $line_num)" >&2
                        ((errors++))
                        continue
                    fi

                    tmp_directions["$crit"]="$direction"
                else
                    echo "Ошибка формата направления: '$line' (строка $line_num)" >&2
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
                        "ИЗВЕСТНОЕ_СОСТОЯНИЕ")
                            if [[ -n "$value" ]]; then
                                tmp_known_state="$value"
                            fi
                            ;;
                        "КОЭФФИЦИЕНТ_ГУРВИЦА")
                            if [[ "$value" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                                if bc_compare "$value" "0" "ge" && bc_compare "$value" "1" "le"; then
                                    tmp_alpha_hurwitz="$value"
                                else
                                    echo "Ошибка: коэффициент Гурвица вне диапазона 0-1: $value (строка $line_num)" >&2
                                    ((errors++))
                                fi
                            else
                                echo "Ошибка: некорректный коэффициент Гурвица: $value (строка $line_num)" >&2
                                ((errors++))
                            fi
                            ;;
                        "ПОРОГ_РАВЕНСТВА")
                            if [[ "$value" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                                if bc_compare "$value" "0" "ge"; then
                                    tmp_equality_threshold="$value"
                                else
                                    echo "Ошибка: порог равенства отрицательный: $value (строка $line_num)" >&2
                                    ((errors++))
                                fi
                            else
                                echo "Ошибка: некорректный порог равенства: $value (строка $line_num)" >&2
                                ((errors++))
                            fi
                            ;;
                        "ПОРОГ_КВАЗИРАВЕНСТВА")
                            if [[ "$value" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                                if bc_compare "$value" "0" "ge"; then
                                    # Автоматическая корректировка для нормализованных значений
                                    if bc_compare "$value" "0.01" "lt"; then
                                        echo "Предупреждение: порог квазиравенства $value слишком мал, установлен 0.01" >&2
                                        tmp_quasiequality_threshold="0.01"
                                    elif bc_compare "$value" "1.0" "gt"; then
                                        echo "Предупреждение: порог квазиравенства $value слишком велик для нормализованных значений, установлен 0.5" >&2
                                        tmp_quasiequality_threshold="0.5"
                                    else
                                        tmp_quasiequality_threshold="$value"
                                    fi
                                else
                                    echo "Ошибка: порог квазиравенства отрицательный: $value (строка $line_num)" >&2
                                    ((errors++))
                                fi
                            else
                                echo "Ошибка: некорректный порог квазиравенства: $value (строка $line_num)" >&2
                                ((errors++))
                            fi
                            ;;
                        "ГЛАВНЫЙ_КРИТЕРИЙ")
                            if [[ -n "$value" ]]; then
                                tmp_main_criterion="$value"
                            fi
                            ;;
                        *)
                            echo "Предупреждение: неизвестный параметр: $param (строка $line_num)" >&2
                            ;;
                    esac
                fi
                ;;

            "Трехмерная матрица")
                # Игнорировать комментарии
                [[ "$line" =~ ^[[:space:]]*# ]] && continue

                # Разделение по запятым с учетом возможных пробелов
                IFS=',' read -r alt state crit value <<< "$line"

                alt=$(echo "$alt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                state=$(echo "$state" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                crit=$(echo "$crit" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                # Проверка, что все поля заполнены
                if [[ -z "$alt" || -z "$state" || -z "$crit" || -z "$value" ]]; then
                    # Пропускаем неполные строки (могут быть пустыми или с комментариями)
                    continue
                fi

                # Проверка существования альтернативы, состояния и критерия
                if ! __exists_in_array tmp_alternatives "$alt"; then
                    echo "Ошибка: альтернатива '$alt' не объявлена (строка $line_num)" >&2
                    ((errors++))
                    continue
                fi

                if ! __exists_in_array tmp_states "$state"; then
                    echo "Ошибка: состояние '$state' не объявлено (строка $line_num)" >&2
                    ((errors++))
                    continue
                fi

                if ! __exists_in_array tmp_criteria "$crit"; then
                    echo "Ошибка: критерий '$crit' не объявлен (строка $line_num)" >&2
                    ((errors++))
                    continue
                fi

                # Проверка числового значения
                if [[ ! "$value" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                    echo "Ошибка: некорректное значение '$value' (строка $line_num)" >&2
                    ((errors++))
                    continue
                fi

                tmp_payoffs["$alt,$state,$crit"]="$value"
                ;;
        esac
    done <<< "$template"

    # 4. Проверка полноты данных
    if [[ ${#tmp_alternatives[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы альтернативы" >&2
        ((errors++))
    fi

    if [[ ${#tmp_criteria[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы критерии" >&2
        ((errors++))
    fi

    if [[ ${#tmp_states[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы состояния среды" >&2
        ((errors++))
    fi

    # Проверка наличия весов для всех критериев
    for crit in "${tmp_criteria[@]}"; do
        if [[ -z "${tmp_weights[$crit]+isset}" ]]; then
            echo "Предупреждение: не задан вес для критерия '$crit'" >&2
        fi
    done

    # Проверка наличия всех значений в трехмерной матрице
    local expected_count=$((${#tmp_alternatives[@]} * ${#tmp_states[@]} * ${#tmp_criteria[@]}))
    local actual_count=${#tmp_payoffs[@]}

    if [[ $expected_count -ne $actual_count ]]; then
        echo "Ошибка: не хватает значений в трехмерной матрице (ожидается: $expected_count, найдено: $actual_count)" >&2
        echo "Отсутствующие значения:" >&2
        for alt in "${tmp_alternatives[@]}"; do
            for state in "${tmp_states[@]}"; do
                for crit in "${tmp_criteria[@]}"; do
                    if [[ -z "${tmp_payoffs[$alt,$state,$crit]+isset}" ]]; then
                        echo "  - $alt, $state, $crit" >&2
                    fi
                done
            done
        done
        ((errors++))
    fi

    # 5. Применение данных только если нет ошибок
    if [[ $errors -gt 0 ]]; then
        echo "Импорт отменен из-за $errors ошибок" >&2
        return 1
    fi

    # Применение данных
    data_cleanup

    # Копирование данных из временных структур
    ALTERNATIVES=("${tmp_alternatives[@]}")
    CRITERIA=("${tmp_criteria[@]}")
    STATES=("${tmp_states[@]}")

    for key in "${!tmp_weights[@]}"; do
        CRITERIA_WEIGHTS["$key"]="${tmp_weights[$key]}"
    done

    for key in "${!tmp_justifications[@]}"; do
        CRITERIA_JUSTIFICATION["$key"]="${tmp_justifications[$key]}"
    done

    for key in "${!tmp_directions[@]}"; do
        CRITERIA_DIRECTIONS["$key"]="${tmp_directions[$key]}"
    done

    for key in "${!tmp_probabilities[@]}"; do
        STATE_PROBABILITIES["$key"]="${tmp_probabilities[$key]}"
    done

    for key in "${!tmp_payoffs[@]}"; do
        PAYOFF_3D["$key"]="${tmp_payoffs[$key]}"
    done

    # Установка параметров
    CURRENT_KNOWN_STATE="${tmp_known_state:-$DEFAULT_KNOWN_STATE}"
    CURRENT_ALPHA_HURWITZ="${tmp_alpha_hurwitz:-$DEFAULT_ALPHA_HURWITZ}"
    EQUALITY_THRESHOLD="${tmp_equality_threshold:-0.1}"
    QUASI_EQUALITY_THRESHOLD="${tmp_quasiequality_threshold:-1.0}"

    # Находим индекс главного критерия
    MAIN_CRITERION_INDEX=0
    if [[ -n "$tmp_main_criterion" ]]; then
        for ((i=0; i<${#CRITERIA[@]}; i++)); do
            if [[ "${CRITERIA[$i]}" == "$tmp_main_criterion" ]]; then
                MAIN_CRITERION_INDEX=$i
                break
            fi
        done
    fi

    CURRENT_TEMPLATE="$tmp_template"

    # Нормализация весов и вероятностей
    __normalize_all

    echo "Импорт успешен: ${#ALTERNATIVES[@]} альтернатив, ${#CRITERIA[@]} критериев, ${#STATES[@]} состояний" >&2
    return 0
}

__normalize_all() {
    local started_here=0

    if ! __progress_is_active; then
        zenity_progress_start "Нормализация" "Нормализация весов и вероятностей..." || true
        started_here=1
    fi

    # гарантированно закроем прогресс, если мы его открыли
    if [[ "$started_here" -eq 1 ]]; then
        trap 'zenity_progress_stop' RETURN
    fi

    __progress_update 0 "Старт нормализации..." || true

    __normalize_weights 0 50   || return 1
    __normalize_probabilities 50 50 || return 1

    __progress_update 100 "Нормализация завершена" || true
    return 0
}

__progress_is_active() {
    [[ -n "${PROGRESS_PID:-}" ]] && kill -0 "$PROGRESS_PID" 2>/dev/null && { : >&3; } 2>/dev/null
}

__progress_update() {
    local pct="${1:-0}"
    local msg="${2:-}"

    if __progress_is_active; then
        echo "$pct" >&3
        [[ -n "$msg" ]] && echo "# $msg" >&3
    fi
}

__progress_map() {
    # base + span * local_pct/100
    local base="$1" span="$2" local_pct="$3"
    echo $(( base + (span * local_pct) / 100 ))
}

__normalize_weights() {
    local base="${1:-0}"
    local span="${2:-50}"

    [[ ${#CRITERIA[@]} -eq 0 ]] && {
        echo "Ошибка: нет критериев для нормализации весов" >&2
        return 1
    }

    __progress_update "$(__progress_map "$base" "$span" 5)" "Веса: расчёт суммы..." || true

    # Сумма одним bc-вызовом
    local expr="0"
    local crit w
    for crit in "${CRITERIA[@]}"; do
        w=$(normalize_number "${CRITERIA_WEIGHTS[$crit]:-0}")
        expr="$expr + ($w)"
    done
    local weight_sum
    weight_sum=$(bc_calc "$expr")

    # Если сумма 0 — равномерно
    if bc_compare "$weight_sum" "0" "eq"; then
        __progress_update "$(__progress_map "$base" "$span" 20)" "Веса: не заданы, ставлю равномерно..." || true
        local equal_weight
        equal_weight=$(bc_calc "100 / ${#CRITERIA[@]}")
        for crit in "${CRITERIA[@]}"; do
            CRITERIA_WEIGHTS["$crit"]="$equal_weight"
        done
        __progress_update "$(__progress_map "$base" "$span" 100)" "Веса: готово" || true
        return 0
    fi

    # Нормализуем, если нужно
    local diff
    diff=$(bc_calc "abs($weight_sum - 100)")

    if bc_compare "$diff" "0.1" "gt"; then
        __progress_update "$(__progress_map "$base" "$span" 35)" "Веса: нормализация к 100%..." || true
        local i=0 n=${#CRITERIA[@]}
        for crit in "${CRITERIA[@]}"; do
            ((i++))
            __progress_update "$(__progress_map "$base" "$span" $((35 + (45*i)/n)) )" "Веса: $crit"
            w=$(normalize_number "${CRITERIA_WEIGHTS[$crit]:-0}")
            CRITERIA_WEIGHTS["$crit"]=$(bc_calc "$w * 100 / $weight_sum")
        done
    else
        __progress_update "$(__progress_map "$base" "$span" 70)" "Веса: нормализация не требуется" || true
    fi

    # Контроль суммы
    __progress_update "$(__progress_map "$base" "$span" 85)" "Веса: контроль суммы..." || true
    expr="0"
    for crit in "${CRITERIA[@]}"; do
        w=$(normalize_number "${CRITERIA_WEIGHTS[$crit]:-0}")
        expr="$expr + ($w)"
    done

    local final_sum final_diff
    final_sum=$(bc_calc "$expr")
    final_diff=$(bc_calc "abs($final_sum - 100)")

    if bc_compare "$final_diff" "0.01" "gt"; then
        echo "Ошибка: сумма весов после нормализации $(LANG=C printf \"%.4f\" \"$final_sum\")% отличается от 100%" >&2
        return 1
    fi

    __progress_update "$(__progress_map "$base" "$span" 100)" "Веса: готово" || true
    return 0
}

__normalize_probabilities() {
    local base="${1:-50}"
    local span="${2:-50}"

    [[ ${#STATES[@]} -eq 0 ]] && {
        echo "Ошибка: нет состояний для нормализации вероятностей" >&2
        return 1
    }

    __progress_update "$(__progress_map "$base" "$span" 5)" "Вероятности: расчёт суммы..." || true

    # Сумма одним bc-вызовом
    local expr="0"
    local state p
    for state in "${STATES[@]}"; do
        p=$(normalize_number "${STATE_PROBABILITIES[$state]:-0}")
        expr="$expr + ($p)"
    done

    local prob_sum
    prob_sum=$(bc_calc "$expr")

    # Если сумма 0 — равномерно
    if bc_compare "$prob_sum" "0" "eq"; then
        __progress_update "$(__progress_map "$base" "$span" 20)" "Вероятности: не заданы, ставлю равномерно..." || true
        local equal_prob
        equal_prob=$(bc_calc "1 / ${#STATES[@]}")
        for state in "${STATES[@]}"; do
            STATE_PROBABILITIES["$state"]="$equal_prob"
        done
        __progress_update "$(__progress_map "$base" "$span" 100)" "Вероятности: готово" || true
        return 0
    fi

    # Нормализуем, если нужно
    local diff
    diff=$(bc_calc "abs($prob_sum - 1)")

    if bc_compare "$diff" "0.01" "gt"; then
        __progress_update "$(__progress_map "$base" "$span" 35)" "Вероятности: нормализация к 1.0..." || true
        local i=0 n=${#STATES[@]}
        for state in "${STATES[@]}"; do
            ((i++))
            __progress_update "$(__progress_map "$base" "$span" $((35 + (45*i)/n)) )" "Вероятности: $state" || true
            p=$(normalize_number "${STATE_PROBABILITIES[$state]:-0}")
            STATE_PROBABILITIES["$state"]=$(bc_calc "$p / $prob_sum")
        done
    else
        __progress_update "$(__progress_map "$base" "$span" 70)" "Вероятности: нормализация не требуется" || true
    fi

    # Контроль суммы
    __progress_update "$(__progress_map "$base" "$span" 85)" "Вероятности: контроль суммы..." || true
    expr="0"
    for state in "${STATES[@]}"; do
        p=$(normalize_number "${STATE_PROBABILITIES[$state]:-0}")
        expr="$expr + ($p)"
    done

    local final_sum final_diff
    final_sum=$(bc_calc "$expr")
    final_diff=$(bc_calc "abs($final_sum - 1)")

    if bc_compare "$final_diff" "0.001" "gt"; then
        echo "Ошибка: сумма вероятностей после нормализации $(LANG=C printf \"%.5f\" \"$final_sum\") отличается от 1" >&2
        return 1
    fi

    __progress_update "$(__progress_map "$base" "$span" 100)" "Вероятности: готово" || true
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
        --title="✏️ Редактирование исходных данных для задачи 8" \
        --width=900 --height=700 \
        --font="monospace 11" \
        --editable \
        --filename="$temp_file" 2>/dev/null)

    local zenity_exit_code=$?

    # Очищаем временный файл
    rm -f "$temp_file" 2>/dev/null
    trap - EXIT INT TERM  # Снимаем обработчики

    # Обработка отмены пользователем
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
            --text="Шаблон успешно импортирован!\n\n• Альтернатив: ${#ALTERNATIVES[@]}\n• Критериев: ${#CRITERIA[@]}\n• Состояний среды: ${#STATES[@]}\n• α = $CURRENT_ALPHA_HURWITZ\n• Известное состояние: $CURRENT_KNOWN_STATE" \
            --width=500 2>/dev/null
        CURRENT_TEMPLATE="$edited_data"
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

    echo "Валидация данных задачи 8..." >&2

    # Проверка базовых структур
    if [[ ${#ALTERNATIVES[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы альтернативы" >&2
        errors=1
    else
        echo "  Альтернатив: ${#ALTERNATIVES[@]}" >&2
    fi

    if [[ ${#CRITERIA[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы критерии" >&2
        errors=1
    else
        echo "  Критериев: ${#CRITERIA[@]}" >&2
    fi

    if [[ ${#STATES[@]} -eq 0 ]]; then
        echo "Ошибка: не заданы состояния среды" >&2
        errors=1
    else
        echo "  Состояний среды: ${#STATES[@]}" >&2
    fi

    # Проверка весов критериев
    local weight_sum=0
    for crit in "${CRITERIA[@]}"; do
        if [[ -z "${CRITERIA_WEIGHTS[$crit]+isset}" ]]; then
            echo "Предупреждение: не задан вес для критерия '$crit'" >&2
            warnings=1
        else
            local weight="${CRITERIA_WEIGHTS[$crit]}"
            if ! bc_compare "$weight" "0" "ge"; then
                echo "Ошибка: отрицательный вес для критерия '$crit': $weight" >&2
                errors=1
            fi
            weight_sum=$(bc_calc "$weight_sum + $weight")
        fi
    done

    # Проверка обоснований весов
    for crit in "${CRITERIA[@]}"; do
        if [[ -z "${CRITERIA_JUSTIFICATION[$crit]+isset}" ]]; then
            echo "Предупреждение: не задано обоснование для критерия '$crit'" >&2
            warnings=1
        fi
    done

    # Проверка направлений критериев
    for crit in "${CRITERIA[@]}"; do
        if [[ -z "${CRITERIA_DIRECTIONS[$crit]+isset}" ]]; then
            echo "Ошибка: не задано направление для критерия '$crit'" >&2
            errors=1
        elif [[ "${CRITERIA_DIRECTIONS[$crit]}" != "максимизация" &&
                "${CRITERIA_DIRECTIONS[$crit]}" != "минимизация" ]]; then
            echo "Ошибка: некорректное направление для критерия '$crit': '${CRITERIA_DIRECTIONS[$crit]}'" >&2
            errors=1
        fi
    done

    # Проверка вероятностей состояний
    local prob_sum=0
    for state in "${STATES[@]}"; do
        if [[ -z "${STATE_PROBABILITIES[$state]+isset}" ]]; then
            echo "Предупреждение: не задана вероятность для состояния '$state'" >&2
            warnings=1
        else
            local prob="${STATE_PROBABILITIES[$state]}"
            if ! bc_compare "$prob" "0" "ge"; then
                echo "Ошибка: отрицательная вероятность для состояния '$state': $prob" >&2
                errors=1
            fi
            prob_sum=$(bc_calc "$prob_sum + $prob")
        fi
    done

    # Проверка трехмерной матрицы
    local expected_count=$((${#ALTERNATIVES[@]} * ${#STATES[@]} * ${#CRITERIA[@]}))
    local actual_count=0
    local missing_count=0

    for alt in "${ALTERNATIVES[@]}"; do
        for state in "${STATES[@]}"; do
            for crit in "${CRITERIA[@]}"; do
                if [[ -z "${PAYOFF_3D[$alt,$state,$crit]+isset}" ]]; then
                    echo "Ошибка: отсутствует значение для альтернативы '$alt', состояния '$state', критерия '$crit'" >&2
                    missing_count=$((missing_count + 1))
                    errors=1
                else
                    actual_count=$((actual_count + 1))
                    local value="${PAYOFF_3D[$alt,$state,$crit]}"
                    if ! bc_compare "$value" "0" "ge"; then
                        echo "Предупреждение: отрицательное значение $alt:$state:$crit=$value" >&2
                        warnings=1
                    fi
                fi
            done
        done
    done

    echo "  Ожидалось значений: $expected_count" >&2
    echo "  Найдено значений: $actual_count" >&2
    if [[ $missing_count -gt 0 ]]; then
        echo "  Отсутствует значений: $missing_count" >&2
    fi

    # Проверка суммы весов
    if [[ $errors -eq 0 ]]; then
        local diff=$(bc_calc "abs($weight_sum - 100)")
        if bc_compare "$diff" "0.5" "gt"; then
            echo "Ошибка: сумма весов ($(LANG=C printf "%.2f" "$weight_sum")%) значительно отличается от 100%" >&2
            errors=1
        elif bc_compare "$diff" "0.1" "gt"; then
            echo "Предупреждение: сумма весов ($(LANG=C printf "%.2f" "$weight_sum")%) отличается от 100%" >&2
            warnings=1
        fi
    fi

    # Проверка суммы вероятностей
    if [[ $errors -eq 0 ]]; then
        local diff=$(bc_calc "abs($prob_sum - 1)")
        if bc_compare "$diff" "0.01" "gt"; then
            echo "Ошибка: сумма вероятностей ($(LANG=C printf "%.3f" "$prob_sum")) значительно отличается от 1" >&2
            errors=1
        elif bc_compare "$diff" "0.001" "gt"; then
            echo "Предупреждение: сумма вероятностей ($(LANG=C printf "%.3f" "$prob_sum")) отличается от 1" >&2
            warnings=1
        fi
    fi

    # Проверка известного состояния
    if [[ -n "$CURRENT_KNOWN_STATE" ]]; then
        local found=0
        for state in "${STATES[@]}"; do
            if [[ "$state" == "$CURRENT_KNOWN_STATE" ]]; then
                found=1
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            echo "Ошибка: известное состояние '$CURRENT_KNOWN_STATE' не найдено в списке состояний" >&2
            errors=1
        fi
    else
        echo "Предупреждение: не задано известное состояние" >&2
        warnings=1
    fi

    # Проверка коэффициента Гурвица
    if ! bc_compare "$CURRENT_ALPHA_HURWITZ" "0" "ge" || ! bc_compare "$CURRENT_ALPHA_HURWITZ" "1" "le"; then
        echo "Ошибка: коэффициент Гурвица вне диапазона 0-1: $CURRENT_ALPHA_HURWITZ" >&2
        errors=1
    fi

    # Проверка порогов
    if [[ -n "$EQUALITY_THRESHOLD" ]] && ! bc_compare "$EQUALITY_THRESHOLD" "0" "ge"; then
        echo "Ошибка: отрицательный порог равенства: $EQUALITY_THRESHOLD" >&2
        errors=1
    fi

    if [[ -n "$QUASI_EQUALITY_THRESHOLD" ]] && ! bc_compare "$QUASI_EQUALITY_THRESHOLD" "0" "ge"; then
        echo "Ошибка: отрицательный порог квазиравенства: $QUASI_EQUALITY_THRESHOLD" >&2
        errors=1
    fi

    # Итоги валидации
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

# === ЗАВИСИМОСТИ ===
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
        __display_3d_matrix
        __form_integrated_matrix
        __analyze_certainty
        __analyze_risk
        __analyze_uncertainty
        __final_recommendation
      )
      ;;
  *) zenity_main_menu ;;
esac
