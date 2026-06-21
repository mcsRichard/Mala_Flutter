import 'package:flutter/material.dart';

class _Template {
  final String name;
  final String subtitle;
  const _Template(this.name, this.subtitle);
}

class _Category {
  final String title;
  final List<_Template> items;
  final Color chipColor;
  const _Category(this.title, this.items, this.chipColor);
}

final _categories = [
  _Category('心咒', [
    _Template('金刚萨埵心咒', '六字/百字明'),
    _Template('莲师心咒', '嗡阿吽班扎格鲁'),
    _Template('观音心咒', '六字大明咒'),
    _Template('文殊心咒', '嗡阿Ra巴扎那娑'),
    _Template('度母心咒', '绿度母/白度母'),
    _Template('普巴金刚心咒', '忿怒除障本尊'),
    _Template('药师佛心咒', '增福除病'),
    _Template('阿弥陀佛心咒', '往生净土'),
    _Template('长寿佛心咒', '无量寿佛'),
    _Template('财神心咒', '黄财神/五姓财神'),
    _Template('金刚亥母心咒', '空行智慧母'),
    _Template('马头明王心咒', '忿怒除魔障'),
  ], const Color(0xFFEDE7F6)),
  _Category('经文', [
    _Template('金刚经', '空性智慧'),
    _Template('心经', '般若波罗蜜多'),
    _Template('般若摄颂', '般若波罗蜜多'),
    _Template('地藏菩萨本愿经', '净障消业'),
    _Template('普门品', '观音感应品'),
    _Template('长寿经', '增寿增福'),
    _Template('阿弥陀经', '净土往生'),
    _Template('药师经', '消灾延寿'),
    _Template('大乘离文字经', '普光明藏'),
    _Template('优陀那经', ''),
    _Template('入中论', ''),
    _Template('前行广释', ''),
  ], const Color(0xFFE8F5E9)),
  _Category('前行', [
    _Template('顶礼', '大礼拜·十万次'),
    _Template('皈依', '皈依发心·十万遍'),
    _Template('发心', '菩提心·十万遍'),
    _Template('百字明', '金刚萨埵·十万遍'),
    _Template('供曼扎', '积资·十万次'),
    _Template('莲师上师瑜伽', '祈请莲师·十万次'),
  ], const Color(0xFFE3F2FD)),
  _Category('祈祷文', [
    _Template('上师瑜伽', '法主如意宝等'),
    _Template('三十五佛忏悔文', '净障忏悔'),
    _Template('七支供养', '积资净障'),
    _Template('意乐任运自成', '祈祷文'),
    _Template('心经回遮', '迴遮连续'),
    _Template('供护法', '护法食子'),
    _Template('喇嘛钦', '莲师祈祷文'),
    _Template('二十一度母礼赞', '顶礼文'),
  ], const Color(0xFFFFF3E0)),
];

class PracticeLibraryScreen extends StatelessWidget {
  final void Function(String name) onSelectTemplate;
  final VoidCallback onCustomInput;

  const PracticeLibraryScreen({
    super.key,
    required this.onSelectTemplate,
    required this.onCustomInput,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('功课库')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.tonal(
            onPressed: onCustomInput,
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
            child: const Text('自定义输入'),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (ctx, i) {
          final cat = _categories[i];
          return _CategorySection(
            category: cat,
            onSelect: onSelectTemplate,
          );
        },
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final _Category category;
  final void Function(String) onSelect;

  const _CategorySection({required this.category, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: category.items.map((t) {
            return _TemplateChip(
              template: t,
              color: category.chipColor,
              onTap: () => onSelect(t.name),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final _Template template;
  final Color color;
  final VoidCallback onTap;

  const _TemplateChip(
      {required this.template, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          template.name,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
