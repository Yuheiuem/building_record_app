part of '../building_detail_page.dart';

class _BuildingOverviewSection extends StatelessWidget {
  const _BuildingOverviewSection({
    required this.detail,
    required this.tagsById,
    required this.enableNetworkTiles,
    required this.onRefresh,
    required this.onEditInformation,
    required this.onEditLocation,
    required this.onHideBuilding,
    required this.onDeleteBuildingPermanently,
    required this.onRecordRevisit,
  });

  final BuildingDetailData detail;
  final Map<String, BuildingTag> tagsById;
  final bool enableNetworkTiles;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditInformation;
  final VoidCallback onEditLocation;
  final VoidCallback onHideBuilding;
  final VoidCallback onDeleteBuildingPermanently;
  final VoidCallback onRecordRevisit;

  @override
  Widget build(BuildContext context) {
    final Building building = detail.building;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wideLayout = constraints.maxWidth >= 900;
        final Widget information = _BuildingInformationCard(
          detail: detail,
          tagsById: tagsById,
          onRefresh: onRefresh,
          onEditInformation: onEditInformation,
          onEditLocation: onEditLocation,
          onHideBuilding: onHideBuilding,
          onDeleteBuildingPermanently: onDeleteBuildingPermanently,
          onRecordRevisit: onRecordRevisit,
        );
        final Widget map = _BuildingLocationCard(
          building: building,
          enableNetworkTiles: enableNetworkTiles,
        );

        if (wideLayout) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 3, child: information),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: SizedBox(height: 420, child: map)),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            information,
            const SizedBox(height: 12),
            SizedBox(height: 320, child: map),
          ],
        );
      },
    );
  }
}
