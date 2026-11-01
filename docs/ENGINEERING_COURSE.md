# Курс: инженерный уровень для сложных C++/GPU/визуальных приложений

Дата составления: 2026-06-08.

Цель курса - довести тебя до уровня, где ты можешь самостоятельно проектировать, писать, отлаживать и улучшать приложения уровня `cuLenia`: производительные C++ приложения, симуляторы, визуализаторы, движки, научные инструменты, GPU/CPU hybrid-системы и интерактивные desktop-программы.

Курс не привязан только к Lenia, CUDA или OpenGL. Он строит общий инженерный фундамент: язык, архитектура, математика, память, производительность, графика, вычисления, сборка, тестирование, отладка и выпуск.

## Главный принцип

Ты не "изучаешь темы". Ты каждую тему закрываешь артефактом:

- работающий код;
- тесты;
- замер производительности;
- короткая документация;
- список найденных проблем;
- улучшенная версия после профилирования.

Если темы пройдены без артефактов, навык не сформирован.

## Целевой уровень

После курса ты должен уметь:

- читать чужой C++/CUDA/OpenGL проект и быстро строить карту архитектуры;
- проектировать модульную структуру приложения;
- безопасно управлять ресурсами CPU/GPU через RAII;
- писать математически корректные симуляции;
- переносить вычисления с CPU на GPU;
- сравнивать direct, tiled, FFT и batched подходы;
- строить интерактивную визуализацию;
- профилировать CPU/GPU bottlenecks;
- находить memory bugs и race conditions;
- делать reproducible builds;
- документировать проект так, чтобы другой инженер мог его развивать.

## Предварительные требования

Нужны:

- уверенные базовые знания программирования;
- понимание массивов, указателей, функций, структур;
- готовность писать много маленьких программ;
- Windows/Linux окружение с компилятором C++;
- позже - NVIDIA GPU для CUDA-модулей.

Если C++ пока слабый, первые 6 недель нельзя пропускать.

## Карта курса

Оптимальная длительность: 9 месяцев.

Интенсивный вариант: 4-5 месяцев, если заниматься 25-35 часов в неделю.

Нормальный вариант: 8-12 часов в неделю.

Каждую неделю:

- 40% времени - чтение и разбор чужого кода;
- 45% времени - собственная реализация;
- 10% времени - тесты и профилирование;
- 5% времени - журнал решений.

## Уровень 1. Modern C++ и системное мышление

Длительность: 4-6 недель.

### Темы

- компиляция, линковка, translation units;
- stack, heap, lifetime, ownership;
- pointers, references, const correctness;
- RAII;
- rule of zero/five;
- move semantics;
- `std::vector`, `std::array`, `std::span`, `std::unique_ptr`;
- error handling без хаоса;
- interfaces и dependency boundaries;
- basic profiling через timers.

### Практика

1. Напиши `Image` класс для RGBA float buffer:
   - хранение `width`, `height`, pixels;
   - bounds checks в debug;
   - save/load PPM или BMP;
   - операции `clear`, `blend`, `sample`.

2. Напиши RAII wrappers:
   - `FileHandle`;
   - `Timer`;
   - `Buffer<T>`;
   - позже по аналогии `CudaBuffer<T>` и `GlBuffer`.

3. Напиши маленький CPU particle simulation:
   - 10 000 частиц;
   - update loop;
   - простая spatial grid;
   - экспорт кадров в изображения.

### Критерий готовности

Ты можешь объяснить, кто владеет каждым ресурсом в программе, где он создается, где освобождается и почему утечки невозможны при early return.

### Источники

- [C++ Core Guidelines](https://github.com/isocpp/CppCoreGuidelines)
- [cppreference](https://en.cppreference.com/w/cpp/)
- [Microsoft: Object lifetime and RAII](https://learn.microsoft.com/en-us/cpp/cpp/object-lifetime-and-resource-management-modern-cpp)

## Уровень 2. Build-системы, зависимости и структура проекта

Длительность: 3-4 недели.

### Темы

- CMake targets;
- include directories;
- static/shared libraries;
- Debug/Release;
- compiler warnings;
- package managers;
- project layout;
- reproducible setup;
- CI basics;
- config files.

### Практика

1. Перепиши маленький проект на CMake:
   - `src`;
   - `include`;
   - `tests`;
   - `tools`;
   - `examples`.

2. Добавь зависимости через `vcpkg`:
   - `fmt`;
   - `glfw`;
   - `glm`;
   - `gtest` или `catch2`.

3. Сделай `README`:
   - как собрать;
   - как запустить;
   - как тестировать;
   - какие known limitations.

### Критерий готовности

Ты можешь создать новый C++ проект так, чтобы другой человек собрал его одной командой без ручного копирования библиотек.

### Источники

- [CMake Tutorial](https://cmake.org/cmake/help/latest/guide/tutorial/index.html)
- [CMake CUDA support](https://cmake.org/cmake/help/latest/manual/cmake-cuda.7.html)
- [vcpkg overview](https://learn.microsoft.com/en-us/vcpkg/get_started/overview)
- [MSBuild C++ reference](https://learn.microsoft.com/en-us/cpp/build/reference/msbuild-reference-cpp)

## Уровень 3. Тестирование, диагностика и надежность

Длительность: 3-4 недели.

### Темы

- unit tests;
- golden tests;
- property-style tests;
- deterministic randomness;
- floating point tolerance;
- logging;
- assertions;
- sanitizers;
- benchmark harness;
- regression tests.

### Практика

1. Для `Image` и particle simulation добавь тесты:
   - корректный размер;
   - корректная индексация;
   - стабильный результат при fixed seed;
   - сравнение float output с tolerance.

2. Напиши benchmark:
   - update time;
   - memory bandwidth estimate;
   - frames per second;
   - CSV output.

3. Добавь fault cases:
   - неверный config;
   - пустой файл;
   - слишком большой размер;
   - out-of-memory path.

### Критерий готовности

Ты не считаешь программу "готовой", пока у нее нет воспроизводимого запуска, теста корректности и замера скорости.

### Источники

- [GoogleTest Primer](https://google.github.io/googletest/primer.html)
- [Catch2 documentation](https://catch2.org/)

## Уровень 4. Математика для симуляций и визуализации

Длительность: 5-6 недель.

### Темы

- vectors и matrices;
- coordinate systems;
- numerical integration;
- stability;
- finite differences;
- convolution;
- kernels;
- FFT idea;
- sampling, interpolation;
- color spaces;
- probability and random distributions.

### Практика

1. Реализуй 2D convolution на CPU:
   - naive version;
   - separable kernel version;
   - tiled/blocking CPU version;
   - сравнение скорости.

2. Реализуй reaction-diffusion simulation:
   - Gray-Scott model;
   - несколько presets;
   - экспорт PNG/PPM frames.

3. Реализуй FFT convolution через CPU-библиотеку или свою учебную 1D FFT:
   - цель не скорость, а понимание transform/multiply/inverse.

### Критерий готовности

Ты можешь выбрать алгоритм по сложности и данным: когда direct convolution нормальна, когда нужна FFT, когда нужна approximation.

### Источники

- [3Blue1Brown: Essence of Linear Algebra](https://www.3blue1brown.com/topics/linear-algebra)
- [The Scientist and Engineer's Guide to DSP](https://www.dspguide.com/)
- [FFTW documentation](https://www.fftw.org/doc/)

## Уровень 5. CPU performance и data-oriented design

Длительность: 4-5 недель.

### Темы

- cache locality;
- AoS vs SoA;
- branch prediction;
- SIMD basics;
- memory bandwidth;
- false sharing;
- threading;
- task decomposition;
- lock-free basics;
- profiling before optimizing.

### Практика

1. Оптимизируй particle simulation:
   - AoS baseline;
   - SoA version;
   - spatial hashing;
   - multithreaded update.

2. Сделай отчет:
   - before/after timings;
   - flamegraph или profiler screenshots;
   - что реально ускорило код;
   - что не сработало.

3. Напиши CPU renderer:
   - draw circles;
   - alpha blending;
   - parallel tile renderer.

### Критерий готовности

Ты не говоришь "это быстрее" без измерения. Любая оптимизация подтверждается цифрами.

### Источники

- [Intel Intrinsics Guide](https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html)
- [Compiler Explorer](https://godbolt.org/)
- [Tracy Profiler](https://github.com/wolfpld/tracy)

## Уровень 6. Графика: окно, рендер, GPU resources

Длительность: 6-8 недель.

### Темы

- window loop;
- input;
- frame timing;
- OpenGL buffer/texture/shader pipeline;
- texture upload;
- framebuffer;
- shader basics;
- RenderDoc;
- Dear ImGui для debug UI;
- переход от legacy OpenGL к modern pipeline.

### Практика

1. Создай viewer:
   - окно через GLFW;
   - texture на весь экран;
   - zoom/pan;
   - pause/play;
   - screenshot.

2. Перенеси CPU simulation frames в OpenGL texture:
   - сначала через CPU upload;
   - затем double-buffer texture upload.

3. Добавь debug UI:
   - параметры симуляции;
   - FPS;
   - выбранный preset;
   - live reload config.

4. Сделай RenderDoc capture:
   - найди texture;
   - проверь draw call;
   - подпиши resources.

### Критерий готовности

Ты можешь построить приложение, которое стабильно держит окно, input, рендеринг и обновление данных без спутанного глобального состояния.

### Источники

- [GLFW documentation](https://www.glfw.org/docs/)
- [GLEW documentation](https://glew.sourceforge.net/)
- [OpenGL Registry](https://registry.khronos.org/opengl)
- [LearnOpenGL](https://learnopengl.com/)
- [RenderDoc docs](https://renderdoc.org/docs/index.html)
- [Dear ImGui](https://github.com/ocornut/imgui)

## Уровень 7. CUDA и GPU compute

Длительность: 8-10 недель.

### Темы

- CUDA programming model;
- kernels;
- thread indexing;
- memory hierarchy;
- coalesced access;
- shared memory;
- constant memory;
- pinned memory;
- streams/events;
- occupancy;
- error checking;
- Compute Sanitizer;
- Nsight Compute.

### Практика

1. Реализуй CUDA vector operations:
   - add;
   - scale;
   - reduce;
   - prefix sum учебно.

2. Перенеси CPU image filters на CUDA:
   - grayscale;
   - blur;
   - Sobel;
   - convolution.

3. Сделай CUDA reaction-diffusion:
   - CPU reference;
   - CUDA version;
   - correctness diff;
   - benchmark.

4. Оптимизируй CUDA convolution:
   - naive global memory;
   - shared memory tile;
   - constant memory kernel;
   - compare timings.

### Критерий готовности

Ты можешь по profiler output понять, ограничен ли kernel вычислениями, памятью, occupancy или синхронизацией.

### Источники

- [CUDA C++ Programming Guide](https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html)
- [CUDA Runtime API](https://docs.nvidia.com/cuda/cuda-runtime-api/index.html)
- [CUDA 12.3 documentation archive](https://docs.nvidia.com/cuda/archive/12.3.0/)
- [NVIDIA CUDA Samples](https://github.com/NVIDIA/cuda-samples)
- [Compute Sanitizer](https://docs.nvidia.com/cuda/compute-sanitizer/index.html)
- [Nsight Compute](https://docs.nvidia.com/nsight-compute/)
- [Nsight Systems](https://docs.nvidia.com/nsight-systems/UserGuide/index.html)

## Уровень 8. GPU libraries, FFT и interop

Длительность: 6-8 недель.

### Темы

- cuFFT plans;
- batched transforms;
- real-to-complex layout;
- normalization;
- complex multiplication;
- precision tradeoffs;
- CUDA-OpenGL interop;
- GPU-to-GPU data path;
- async compute/render pipeline.

### Практика

1. Реализуй FFT blur:
   - CPU reference;
   - cuFFT version;
   - сравнение direct vs FFT.

2. Сделай GPU-only visualizer:
   - CUDA пишет в PBO;
   - OpenGL рисует texture;
   - без CPU copy на каждом кадре.

3. Добавь switch:
   - CPU direct;
   - CUDA direct;
   - CUDA shared memory;
   - CUDA FFT.

4. Добавь precision modes:
   - FP32;
   - FP64 там, где имеет смысл;
   - half/BF16 как эксперимент.

### Критерий готовности

Ты можешь объяснить каждый data transfer между CPU, CUDA и graphics API, а лишние transfers умеешь убрать.

### Источники

- [cuFFT documentation](https://docs.nvidia.com/cuda/cufft/index.html)
- [CUDA Runtime API: OpenGL Interoperability](https://docs.nvidia.com/cuda/cuda-runtime-api/index.html)
- [NVIDIA CUDA Samples: graphics interop](https://github.com/NVIDIA/cuda-samples)

## Уровень 9. Архитектура сложного приложения

Длительность: 6-8 недель.

### Темы

- module boundaries;
- core/domain/render/platform separation;
- ECS basics, если нужен динамический мир;
- config-driven architecture;
- plugin-like presets;
- command system;
- undo/debug tooling;
- serialization;
- hot reload;
- telemetry;
- documentation-driven development.

### Практика

Собери приложение `SimLab`:

- `core`: math, image, buffers, config;
- `simulation`: CPU/CUDA algorithms;
- `render`: OpenGL viewer;
- `ui`: parameters and debug panels;
- `tests`: correctness and regression tests;
- `bench`: performance measurements;
- `docs`: architecture and user guide.

Минимальные features:

- 3 симуляции: reaction-diffusion, particles, cellular automata;
- CPU и GPU backend хотя бы для одной симуляции;
- live parameter editing;
- save/load presets;
- screenshot/video frame export;
- benchmark mode;
- documented architecture.

### Критерий готовности

Ты можешь добавить новый backend или новую симуляцию без переписывания window loop, renderer и config system.

## Уровень 10. Продвинутый трек: Vulkan, compute abstraction, tools

Длительность: 8-12 недель после основного курса.

Этот уровень нужен, если ты хочешь писать движки и кроссплатформенные realtime tools.

### Темы

- Vulkan instance/device/swapchain;
- command buffers;
- synchronization;
- descriptor sets;
- compute shaders;
- GPU memory allocators;
- render graph;
- frame graph;
- async compute;
- shader tooling;
- abstraction over backends.

### Практика

1. Напиши Vulkan triangle.
2. Напиши textured fullscreen quad.
3. Напиши compute shader image filter.
4. Сделай маленький render graph.
5. Перенеси один viewer с OpenGL на Vulkan.

### Источники

- [Khronos Vulkan Tutorial](https://docs.vulkan.org/tutorial/latest/00_Introduction.html)
- [Vulkan Guide](https://docs.vulkan.org/guide/latest/what_is_vulkan.html)
- [Khronos Vulkan Game Engine Tutorial announcement](https://www.khronos.org/blog/new-vulkan-game-engine-tutorial-build-your-own-production-ready-rendering-engine)

## Портфолио-проекты

Эти проекты лучше делать последовательно. Каждый следующий использует часть предыдущего.

### Проект 1. `PixelLab`

CPU image processing sandbox.

Функции:

- load/save image;
- filters;
- convolution;
- tests;
- benchmark.

Что доказывает:

- C++;
- память;
- тесты;
- базовая математика.

### Проект 2. `FieldSim`

2D scalar/vector field simulator.

Функции:

- reaction-diffusion;
- heat equation;
- advection toy model;
- presets;
- frame export.

Что доказывает:

- численные методы;
- стабильность;
- reproducibility.

### Проект 3. `GpuFilters`

CUDA image filters.

Функции:

- CPU reference;
- CUDA kernels;
- correctness diff;
- benchmark table.

Что доказывает:

- GPU basics;
- memory layout;
- profiling.

### Проект 4. `RealtimeViewer`

OpenGL viewer for live data.

Функции:

- texture renderer;
- pan/zoom;
- UI;
- screenshots;
- RenderDoc-ready labels.

Что доказывает:

- graphics pipeline;
- интерактивное приложение;
- debug UI.

### Проект 5. `GpuSimLab`

Главный выпускной проект.

Функции:

- CPU backend;
- CUDA backend;
- OpenGL interop backend;
- config-driven presets;
- tests;
- profiler report;
- documentation;
- release build.

Что доказывает:

- уровень сложных production-like проектов.

## Как учиться быстрее

### Правило 1. Всегда иметь CPU reference

Перед GPU-версией пиши CPU-версию. Иначе ты не поймешь, ошибка в математике, памяти, kernel indexing или precision.

### Правило 2. Измерять каждую оптимизацию

Формат:

```text
Change:
Expected:
Measured:
Why:
Next:
```

### Правило 3. Писать development journal

Каждый день:

- что сделал;
- что сломалось;
- что измерил;
- что понял;
- какой следующий эксперимент.

### Правило 4. Разбирать чужой код активно

Не просто читать. Делай:

- файл-карту;
- call graph;
- resource ownership map;
- dataflow map;
- список рисков;
- список улучшений.

### Правило 5. Каждые 2 недели делать cleanup pass

Проверять:

- нет ли raw owning pointers;
- нет ли неосвобожденных ресурсов;
- нет ли глобального состояния без причины;
- все ли ошибки проверяются;
- можно ли собрать проект с нуля.

## Что читать дополнительно

### Книги

- Bjarne Stroustrup, `A Tour of C++`.
- Scott Meyers, `Effective Modern C++`.
- Jason Gregory, `Game Engine Architecture`.
- Steve McConnell, `Code Complete`.
- Martin Kleppmann, `Designing Data-Intensive Applications`.
- Richard Szeliski, `Computer Vision: Algorithms and Applications`.
- David Eberly, `3D Game Engine Design`, если пойдешь в графику глубже.

### Репозитории для чтения

- [NVIDIA/cuda-samples](https://github.com/NVIDIA/cuda-samples)
- [ocornut/imgui](https://github.com/ocornut/imgui)
- [glfw/glfw](https://github.com/glfw/glfw)
- [baldurk/renderdoc](https://github.com/baldurk/renderdoc)
- [Chakazul/Lenia](https://github.com/Chakazul/Lenia)

## Контрольная матрица навыков

| Навык | Junior | Strong | Advanced |
| --- | --- | --- | --- |
| C++ ресурсы | вручную освобождает | использует RAII | проектирует resource wrappers |
| Сборка | собирает локально | делает CMake project | делает reproducible multi-config setup |
| Тесты | пишет базовые тесты | тестирует edge cases | строит reference/backends diff tests |
| CPU perf | меряет время | понимает cache/layout | делает data-oriented redesign |
| GPU | пишет kernels | оптимизирует memory access | читает profiler и меняет архитектуру |
| Graphics | рисует texture | строит UI/viewer | отлаживает frame capture |
| Архитектура | пишет функции | разделяет модули | делает расширяемые backend boundaries |
| Документация | описывает запуск | описывает архитектуру | фиксирует tradeoffs и design decisions |

## Экзамен курса

Финальный проект должен иметь:

- сборку одной командой;
- минимум 2 backend implementation;
- минимум 20 unit/regression tests;
- benchmark mode;
- CPU reference для GPU-части;
- интерактивную визуализацию;
- документацию архитектуры;
- список известных ограничений;
- profiler report before/after optimization;
- release package или понятную инструкцию запуска.

Если это выполнено, ты уже способен писать проекты уровня `cuLenia` и лучше.

## Ускоренный план на 12 недель

Если нужно быстро:

| Недели | Фокус | Результат |
| --- | --- | --- |
| 1-2 | Modern C++ + CMake | `PixelLab` |
| 3 | Tests + benchmark | testable image filters |
| 4 | Math + convolution | CPU reaction-diffusion |
| 5 | OpenGL viewer | texture viewer |
| 6-7 | CUDA basics | GPU filters |
| 8 | CUDA convolution | CPU vs GPU comparison |
| 9 | cuFFT | FFT blur/simulation |
| 10 | CUDA-OpenGL interop | GPU-only render path |
| 11 | Architecture cleanup | modular app |
| 12 | Final polish | docs, tests, benchmarks |

Этот вариант тяжелый. Он работает только если ты каждый день пишешь код.

## Лучший следующий шаг

Начни с `PixelLab`.

Минимальная первая версия:

- CMake project;
- `Image` class;
- PPM load/save;
- grayscale;
- blur;
- Sobel;
- GoogleTest или Catch2;
- benchmark;
- README.

После этого переходи к `FieldSim`, затем к `GpuFilters`.

